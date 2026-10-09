--!strict
-- ForestTest (server): THE AMBIENT DRIVE AND THE HUNTER'S STAND, for the playtest world only.
--
-- It owns two things and writes nothing else: WHEN a wave of boars moves, and WHERE a hunter is
-- allowed to stand. It spawns boars through `Runtime:spawnSounder`/`:spawn` and pushes them with
-- THREATS -- it never writes a boar's position, its state or its path. The boar's own owner still
-- decides what a boar does; this only decides what it can see.
--
-- KAREN IS TESTING ALONE IN THE MORNING, which is the whole reason this exists. A driven hunt needs
-- drivers, and she asked for *"each 20s cross 1 flock then 1 big male then on other side few so to
-- be action"* with no second player in the world. So the beaters are PHANTOMS: positions in the
-- threat list with nobody standing on them.
--
-- THAT PATTERN IS NOT NEW HERE. `Match.quickTestPhantom` already injects
-- `{ id, position, kind = "driver" }` to push the quick-test sounder, and it is injected at the
-- same seam for the same reason: a phantom is cheaper, more repeatable and far less code than a
-- fake player, and the Brain cannot tell the difference because there is no difference -- a threat
-- is a position and a kind.
--
-- Design: no new design document. This is a playtest world, behind a world string, reachable only
-- in one place id; the game's own map and drive are untouched. TASKS.md row 122.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Data = require(ReplicatedStorage:WaitForChild("ForestTest"))
-- READ, NEVER WIRED: this module asks `Boar` for ONE number -- how far a boar notices a moving
-- stimulus -- so "was a driver already pushing here" uses the animal's own radius rather than a
-- second copy of it. `Boar` does not require this module, so there is no cycle.
local Boar = require(ServerScriptService:WaitForChild("Boar"))

local Line = require(script.Line)

local ForestTest = {}
ForestTest.Data = Data

-- ---------------------------------------------------------------- the pure half

-- HOW A WAVE BEHAVES, as a function of how long it has been running. Pure: no Instance, no clock,
-- no boar -- so the whole rhythm Karen asked for can be read, and tested, without a world.
--
-- A WAVE IS THREE PHASES.
--   PUSH   a beater stands `behindStuds` NORTH of the group and walks at it. The group runs south,
--          which is the direction the Brain already escapes in, so nothing here fights the animal.
--   TURN   only for a `turnsBack` wave: the northern beater goes and a second appears SOUTH, in
--          front of them, near the road. They break back north. This is Karen's *"several go
--          back"*, and it is what stops the road being a shooting gallery.
--   DONE   no beater at all. Whatever is still on its feet drifts and settles.
--
-- THE BEATER FOLLOWS THE HERD, AND THAT IS THE WHOLE CORRECTION. The first version walked a beater
-- along a line from where the wave was RELEASED, at the field's single `groundY`. Two things were
-- wrong with it and the Director measured both: the animals drift, so a line from where they WERE
-- stops being behind them; and `SENSE.FLUSH_STUDS` is 15 -- a 3D distance -- while the beater stood
-- at y 138 and the animals on ground 40 to 56 studs higher, so the gap alone exceeded the radius
-- and nothing was ever flushed. A beater that cannot be reached is not a beater.
--
-- So a wave keeps its members' handles, takes their live centroid, and stands `pushStuds` behind it
-- AT THEIR OWN HEIGHT. 12 is inside the 15-stud flush radius with room for the centroid to lag.
ForestTest.WAVE = {
	-- LONG ENOUGH FOR A WALK (task 123 round 2): a herd now crosses at 4.5-11 studs/s rather than
	-- 38, so a holding 60-110 studs out takes 13-24 s and the push has to outlast it.
	pushSeconds = 45,
	pushStuds = 11, -- behind the REARMOST animal, inside SENSE.FLUSH_STUDS (15)
	-- 26, AND IT MUST BE OUTSIDE THE FLUSH RADIUS. MEASURED: at 11 studs the turn-back wave ran
	-- HARDER south -- `Brain._senseAware` row 7 is "anything inside a flush radius, whatever state
	-- the animal was in" -> `_flush()` -> FLEE, and FLEE heads for `exitZ`, which is south. A beater
	-- standing in front of a fleeing boar at flush range is not an obstacle, it is more drive.
	--
	-- What turns an animal is AVOID, which rotates it `SENSE.AVOID_TURN_DEG` (120) away from the
	-- cause -- and AVOID is the reaction to something NOTICED but not flushing. So the turning
	-- beater stands between the notice radius (25 standing, 60 moving) and the flush radius (15):
	-- near enough to be seen, far enough to be gone round.
	-- WHERE A TURN-BACK STOPS BEING PUSHED: 95 studs north of the road, and that is measured too.
	--
	-- At 45 the push was still on when they reached it, so they arrived AT A RUN -- FLEE, heading
	-- for `exitZ` -- and crossed before the turning beater could do anything: dz 16 one tick, -8
	-- the next. AVOID cannot swing an animal that is already fleeing past it.
	--
	-- Ending the push at 95 lets them coast the last stretch and come off FLEE, so what meets them
	-- near the road is noticed by a calm animal -- which is the state AVOID is a reaction from. It
	-- also looks like what it is meant to look like: a group that comes down, slows, and thinks.
	-- ...AND THE TURN IS STAGED CLOSER IN (task 123 round 2), because the holdings moved in: 95
	-- studs north of the road was further out than three of the six holdings now start, so a
	-- turning wave would have turned before it had walked anywhere.
	turnAtDz = 40,
	-- ...AND THEY TROT THE LAST STRETCH (task 123 round 4). Karen: *"they can trot when crossing"*.
	-- Inside this far from the road a pushed wave is asked for `PACE.TROT_SPEED` instead of a walk,
	-- so the crossing -- the one part a hunter at a stand actually watches -- is brisker than the
	-- approach, and it is still not a run: only a spook runs them.
	crossTrotDz = 40,
	-- ...and it keeps trotting this far PAST the road, so they clear it instead of slowing on the
	-- gravel in front of the gun.
	crossTrotPastDz = 35,
	-- ...and when it is too late to bother: past this far south they are gone and the stage is over.
	-- THE PASS ACROSS HER FRONT (task 123 round 8). Karen: *"they has to cross like from left to
	-- right or opositi so I can shoot straigh also not only on sides"*.
	--
	-- A lateral wave is pushed SOUTH until it is this far north of the road -- inside the open ground
	-- she is looking at, far enough out to be a shot and near enough to be one -- and then the beater
	-- moves to its FLANK and walks it across her view for `lateralSpan` studs before going back
	-- behind it and putting it over the road.
	-- 55, AND 85 WAS TRIED AND IS WORSE (task 123 round 8). Both were traced against live waves.
	--   55: the `LtoR` wave walked across her front from +86 to -16 studs relative to her stand --
	--       102 studs of broadside, at dz 78 down to 16 -- and then crossed the road 12 studs from
	--       her. That is the pass Karen asked for.
	--   85: the same wave PARKED. Centroid at +127, dz 26, unmoved for 37 seconds: entering the
	--       lateral phase that much earlier leaves the flank beater pushing a herd that has nowhere
	--       it wants to go, and a herd standing still in front of a gun is worse than one that never
	--       came across.
	-- So this is the measured value and the other one is written down rather than re-discovered.
	lateralDz = 55,
	lateralSpan = 150,
	-- WHERE THE EDGE OF THE OPEN IS, for `checkAtTheEdge`. The road's own half width is 20, so 24 is
	-- just outside the verge and 60 is about three body lengths of approach: a band an animal walks
	-- into a few seconds before it would step out onto the ride.
	edgeNearDz = 24,
	edgeFarDz = 60, -- studs across her front: from ~95 studs one side to ~55 the other
	-- The beater stands this far off the flank, inside `SENSE.FLUSH_STUDS` (15) like `pushStuds`,
	-- because a flank beater has to flush as well as a rear one.
	-- 22 AND NOT 11, AND THE REASON WAS ALREADY WRITTEN DOWN IN `wavePhase` ABOVE (task 126).
	--
	-- MEASURED before this task, over a 130 s trace of two lateral waves: the LEFT-TO-RIGHT pass
	-- travelled **18.9 studs** across her front and the RIGHT-TO-LEFT one **68.0**, against a
	-- `lateralSpan` of 150 -- so neither pass finished, which is the open item from task 123 round 8
	-- ("the R-to-L pass never crosses her front"). THE DIRECTION WAS NEVER WRONG: LtoR moved -X and
	-- RtoL moved +X, both correct, and the measurement is what showed that. The span was.
	--
	-- WHY IT WAS SHORT: a beater 11 studs away is INSIDE `SENSE.FLUSH_STUDS` (15), so row 7 of
	-- `Brain:_senseAware` fires, the herd goes to FLEE, and FLEE heads for `field.exitZ` -- SOUTH.
	-- The lateral push and the southward route add up to a diagonal, and the herd reaches the road
	-- long before it has walked 150 studs across her front. `wavePhase`'s own comment measured
	-- exactly this effect for the turn-back case and never applied it here.
	--
	-- At 22 studs the beater is outside the flush band and inside the notice band, so the herd AVOIDs
	-- instead of fleeing -- and `Brain.avoidTarget` turns `SENSE.AVOID_TURN_DEG` off the line toward
	-- the cause, which IS a lateral escape. The after-trace is what says whether that is enough.
	lateralPushStuds = 22,
}

-- "turn" IS GONE (task 122 round 2). `wavePhase`'s `turnsBack` branch only ever answered "done" or
-- "push" -- the turn was tried three ways against the live world, all three crossed anyway, and what
-- shipped was a push that STOPS. The branch that read the word, and the four numbers that fed it,
-- were unreachable for every wave. Archived with the measurements in
-- `backups/2026-10-06-forest-test-turn-phase.md` (rule 7).
export type Phase = "push" | "lateral" | "done"

-- A TURN IS DECIDED BY WHERE THEY ARE, NOT BY A STOPWATCH, and that is measured. On a timer at 9
-- seconds, wave 3 had ALREADY crossed the road at about 8 -- the trace shows it at dz -53 when the
-- turn began, so the "turn-back" was staged behind animals that were gone, and they carried on
-- south. A turn has to happen while they are still north of the road, and near enough to it that
-- the hunter watches them think about it.
--
-- `dz` is the herd's distance north of the road: positive north, negative across.
function ForestTest.wavePhase(
	elapsed: number,
	turnsBack: boolean,
	dz: number?,
	lateral: string?,
	travelled: number?
): Phase
	local wave = ForestTest.WAVE
	-- A TURN-BACK IS A PUSH THAT STOPS, AND THAT IS WHAT THIS BRAIN CAN ACTUALLY DO.
	--
	-- Three versions were measured against the live world and all three CROSSED:
	--   a beater 11 studs ahead  -- inside `SENSE.FLUSH_STUDS` (15), so row 7 of `_senseAware`
	--                               fires and FLEE heads for `exitZ`. More drive, not a turn.
	--   a beater 26 studs ahead  -- outside flush, but staged on the FOREMOST animal it chased the
	--                               one that had bolted: gap 261 studs, visible to nobody.
	--   staged on the centroid   -- correct place, but the herd closes on it, the gap falls under
	--                               15 (measured 12.8) and row 7 fires anyway.
	--
	-- What turns an animal is AVOID, and AVOID is a reaction a CALM animal has. One that is already
	-- fleeing past a threat cannot be swung by it. Making that work reliably is a change to
	-- `Brain`'s precedence -- a different task, and the Director's instruction was not to touch the
	-- boar's axis -- so this does the thing that is honestly available: it STOPS PUSHING at
	-- `turnAtDz`. They coast in, come off FLEE and settle north of the road, which from a stand
	-- reads as a group that came down and thought better of it.
	--
	-- WHAT IT IS NOT is Karen's "go back" as an animation of refusal. That gap is in the report.
	--
	-- ACROSS HER FRONT FIRST, THEN OVER THE ROAD (task 123 round 8). Three steps and no new state
	-- machine: come south into the band, walk ACROSS it, then carry on south. `travelled` is how far
	-- the herd has moved along the lateral axis since the walk began, and the DRIVE measures it
	-- (`ForestTest.lateralTravel`) so this stays pure and a spec can drive all three steps with no
	-- boars at all.
	if lateral ~= nil then
		if dz ~= nil and dz > wave.lateralDz then
			return "push" -- still coming south: get into the band she is looking at
		end
		if elapsed >= wave.pushSeconds then
			return "done"
		end
		if (travelled or 0) < wave.lateralSpan then
			return "lateral"
		end
		return "push" -- the pass is done; put them over the road
	end
	if turnsBack then
		if dz ~= nil and dz <= wave.turnAtDz then
			return "done"
		end
		if elapsed >= wave.pushSeconds then
			return "done"
		end
		return "push"
	end
	if elapsed < wave.pushSeconds then
		return "push"
	end
	return "done"
end

-- WHERE A HERD IS: its centroid, its REARMOST animal and its FOREMOST, or nil when none is left.
-- Dead and despawned members drop out by themselves -- a handle whose part has left the world is
-- not counted.
--
-- REAR AND FRONT ARE WHY THIS RETURNS THREE THINGS. A sounder spreads over 30 studs and
-- `SENSE.FLUSH_STUDS` is 15, so a beater 12 studs from the CENTROID can be 27 from the animal
-- nearest it and flush nobody. MEASURED: lone boars crossed the road in 5 seconds while a sounder
-- of six moved one stud in twenty-four. Pushing the REARMOST animal puts the beater inside the
-- flush radius of at least one of them, and the panic spreads from there -- which is what
-- `SENSE.PANIC_DELAY_SECONDS` exists for.
function ForestTest.herdShape(handles): (Vector3?, Vector3?, Vector3?)
	local sum, n = Vector3.zero, 0
	local rear, front = nil, nil
	for _, handle in ipairs(handles) do
		local part = handle and handle.part
		if part ~= nil and part.Parent ~= nil then
			local at = part.Position
			sum += at
			n += 1
			-- North is +Z here, so the REAR of a herd being pushed south is its largest Z.
			if rear == nil or at.Z > (rear :: Vector3).Z then
				rear = at
			end
			if front == nil or at.Z < (front :: Vector3).Z then
				front = at
			end
		end
	end
	if n == 0 then
		return nil, nil, nil
	end
	return sum / n, rear, front
end

function ForestTest.herdCentre(handles): Vector3?
	local centre = ForestTest.herdShape(handles)
	return centre
end

-- WHERE THAT WAVE'S BEATER IS, or nil when there is none.
--
-- It stands behind the REARMOST animal to push, and in front of the FOREMOST to turn -- never
-- relative to the centroid, which is the middle of a spread nobody is standing in.
-- WHICH WAY A LATERAL PASS TRAVELS, in world X. Pure, and it is the ONE place the mapping from
-- Karen's left and right to the world's axes is written down: she faces NORTH (+Z), and a CFrame
-- looking down +Z has `RightVector` -X -- so her RIGHT is -X, her LEFT is +X, and a LEFT-TO-RIGHT
-- pass travels from +X toward -X. Getting this backwards would put every "broadside" pass behind
-- her, so it is a named function rather than a sign buried in an expression.
function ForestTest.lateralSign(lateral: string?): number
	if lateral == "LtoR" then
		return -1
	elseif lateral == "RtoL" then
		return 1
	end
	return 0
end

-- HOW FAR A LATERAL WAVE HAS WALKED ACROSS HER FRONT, in studs, or nil before it has reached the
-- band at all (task 123 round 8). The DRIVE measures it, because the drive owns the wave record;
-- the pure rule above only has to be told the number.
--
-- THE ORIGIN IS LATCHED WHEN THE BAND IS REACHED, not taken from the release point: a wave that
-- comes south at an angle has already moved in X by the time it arrives, and measuring the span
-- from where it was RELEASED would end the walk before it had begun. Signed, so drifting back the
-- way it came does not count as progress.
function ForestTest.lateralTravel(wave, centre: Vector3, dz: number): number?
	if wave.lateral == nil then
		return nil
	end
	if wave.lateralFromX == nil then
		if dz > ForestTest.WAVE.lateralDz then
			return nil
		end
		wave.lateralFromX = centre.X
	end
	return (centre.X - wave.lateralFromX) * ForestTest.lateralSign(wave.lateral)
end

-- THE PARAMETERS ARE NAMED FOR WHAT THEY ACTUALLY RECEIVE (task 123 round 8). They were `rear` and
-- `front`, and both callers pass the herd's CENTROID and its REARMOST -- so the push was being
-- staged on the centroid while the signature said rear, and the turn on the rearmost while the
-- signature said front. The arithmetic below is byte-for-byte what it was; only the names changed,
-- because a parameter that lies is how the next reader stages a beater in the wrong place.
-- `rear` WENT WITH THE TURN (task 122 round 2): the only phase that used the herd's rearmost animal
-- was the unreachable one, and a parameter nothing reads is the next reader's trap. `herdShape`
-- still ANSWERS the rear and the foremost -- they are facts about a herd, and a later phase may want
-- them -- but the two callers now take only the centroid they use.
function ForestTest.beaterPosition(
	centre: Vector3,
	elapsed: number,
	turnsBack: boolean,
	dz: number?,
	lateral: string?,
	travelled: number?
): Vector3?
	local wave = ForestTest.WAVE
	local phase = ForestTest.wavePhase(elapsed, turnsBack, dz, lateral, travelled)
	if phase == "lateral" then
		-- ON THE FLANK THEY CAME FROM, so the push is ACROSS her view and not into it -- and at the
		-- herd's OWN z, because a beater north of them pushes them south, which is the one thing
		-- this phase exists to postpone.
		local sign = ForestTest.lateralSign(lateral)
		return Vector3.new(centre.X - sign * wave.lateralPushStuds, centre.Y, centre.Z)
	end
	if phase == "push" then
		return centre + Vector3.new(0, 0, wave.pushStuds)
	end
	return nil
end

-- WHICH REPORTING PERIOD WE ARE IN (task 124). Pure: when the world started and what time it is now,
-- in; the drive's number (counting from 1) and how many seconds are left in it, out.
--
-- It is a WINDOW OVER A CLOCK and not a state machine, which is why it needs no state: at any instant
-- the answer is the same arithmetic, so a restarted script, a late join and a spec all agree.
function ForestTest.driveIndexAt(startedAt: number, now: number, seconds: number): (number, number)
	local length = math.max(1, seconds)
	local elapsed = math.max(0, now - startedAt)
	local index = math.floor(elapsed / length) + 1
	return index, length - (elapsed % length)
end

-- WHICH WAVE IS DUE. The cycle repeats forever, so a playtest never runs out of action.
function ForestTest.waveAt(index: number)
	local cycle = Data.SCHEDULE.cycle
	return cycle[((index - 1) % #cycle) + 1]
end

-- WHERE A HUNTER IS PUT when he picks stand `index`, and whether a position is still within his
-- leash. Pure, so the leash is one rule and not one rule per caller.
function ForestTest.withinLeash(position: Vector3, standIndex: number): boolean
	local home = Data.standPosition(standIndex)
	local flat = Vector3.new(position.X - home.X, 0, position.Z - home.Z)
	return flat.Magnitude <= Data.PICK.leashStuds
end

-- THE NEAREST STAND to a position, which is how a hunter picks one: he walks to it. Karen asked for
-- a square to select and save; standing on it IS the selection, and the save is the timer running
-- out or the player confirming -- neither of which this function needs to know about.
function ForestTest.nearestStand(position: Vector3): number
	local best, bestDistance = 1, math.huge
	for index = 1, Data.STAND_COUNT do
		local stand = Data.standPosition(index)
		local flat = Vector3.new(position.X - stand.X, 0, position.Z - stand.Z)
		if flat.Magnitude < bestDistance then
			best, bestDistance = index, flat.Magnitude
		end
	end
	return best
end

-- ---------------------------------------------------------------- the live half

local state = {
	started = false,
	runtime = nil :: any,
	startedAt = 0,
	nextWaveAt = 0,
	waveIndex = 0,
	active = {} :: { { centre: Vector3, handles: { any }, at: number, turnsBack: boolean, id: string } },
	picks = {} :: { [number]: { index: number, lockedAt: number? } },
	released = 0,
	-- TASK 127. Declared here rather than springing into existence in `start`, so `stats()` on a
	-- module that has not been started -- which is exactly what a harness query gets, because MCP's
	-- `require` answers a fresh copy -- reads zeros instead of indexing nil.
	lines = {} :: { any },
	rng = Random.new(),
	stuck = 0,
}

-- THIS WORLD'S BOAR CONFIG, AND NOT THE MODULE'S (task 122 round 2).
--
-- `ForestTestBoot` builds the boar runtime with a world config -- `KINDS` on, `MODEL`, `CALM`,
-- `PACE`, `MOVE` and `LINE` turned on -- and `Boar.newRuntime` merges that over the module's own
-- table. `Boar.CONFIG` is therefore the DEFAULTS, which in this place are the wrong answer to every
-- question this file asks: the Reviewer found `releaseLine` reading `KINDS.ENABLED` from it and
-- spawning a line of nine males because the flag it follows is off by default.
--
-- One source of truth, asked once, with the module as the answer only before a runtime exists (a
-- spec driving the pure half, or the moments before `ForestTest.start`).
local function boarConfig()
	local runtime = state.runtime
	if runtime ~= nil and type(runtime.config) == "function" then
		return runtime:config()
	end
	return Boar.CONFIG
end

function ForestTest.stats()
	return {
		started = state.started,
		waves = state.waveIndex,
		released = state.released,
		-- TASK 127: what the line mode is doing, so the proof reads numbers rather than inferring them.
		lines = #(state.lines or {}),
		stuck = state.stuck or 0,
		active = #state.active,
		boars = if state.runtime then state.runtime:count() else 0,
	}
end

-- EVERY THREAT A BOAR CAN SEE IN THIS WORLD: the real players who are not hunters standing still,
-- plus the phantom beaters. Handed to the boar world at the composition root, exactly where
-- `Match.boarThreats` is handed over in the DEV place.
--
-- A HUNTER IS NOT A DRIVER. He is still a threat -- `kind = "shooter"` -- which with
-- `BOAR_BEHAVIOUR` on is noticed at 25 studs and flushes at 15, so a boar will not walk into him.
-- What he must not do is push the wave: that is the beater's job, and a hunter who pushed would
-- make the animals cross somewhere he is not.
function ForestTest.boarThreats(now: number)
	local out = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character.PrimaryPart
		if root then
			table.insert(out, { id = tostring(player.UserId), position = root.Position, kind = "shooter" })
		end
	end
	for _, wave in ipairs(state.active) do
		local centre = ForestTest.herdShape(wave.handles)
		if centre ~= nil then
			local dz = (centre :: Vector3).Z - Data.roadZ((centre :: Vector3).X)
			local at = ForestTest.beaterPosition(
				centre :: Vector3,
				now - wave.at,
				wave.turnsBack,
				dz,
				wave.lateral,
				ForestTest.lateralTravel(wave, centre :: Vector3, dz)
			)
			if at then
				-- `phantom = true` (task 123 round 5): NOBODY IS STANDING HERE. A real driver inside
				-- `PACE.DRIVER_RUN_STUDS` makes a herd run; this beater is 11 studs behind the
				-- rearmost animal by construction, so without the mark every wave would run for its
				-- whole crossing -- which is exactly what round 4 stopped.
				table.insert(out, { id = wave.id, position = at, kind = "driver", phantom = true })
			end
		end
	end
	return out
end

-- THE LIVE READER over this world's own start time (task 124). It lives below `state` because that is
-- where `state` exists; the arithmetic above it is pure and testable without one.
function ForestTest.drive(now: number)
	-- `state.startedAt` IS A NUMBER, ALWAYS: it is initialised to 0 and `ForestTest.start` sets it
	-- before the first heartbeat. The `or now` that used to be here could never fire -- 0 is truthy
	-- in Luau -- so it read as a guard and was none (task 122 round 2).
	local index, left = ForestTest.driveIndexAt(state.startedAt, now, Data.DRIVE.seconds)
	return { index = index, secondsLeft = left }
end

-- WHERE THE HUNTER IS STANDING, in world X, for aiming the waves at him (task 123 round 8). The
-- stand he LOCKED; the default stand's x until he has locked one, which is also the answer with
-- nobody playing at all.
function ForestTest.hunterStandX(): number
	-- The LOCKED pick wins: an OPEN one is a hunter still choosing, and aiming a wave at a stand he
	-- is about to walk away from is worse than aiming at the default.
	for _, pick in pairs(state.picks) do
		if pick.lockedAt ~= nil then
			return Data.standX(pick.index)
		end
	end
	return Data.standX(Data.PICK.defaultIndex)
end

-- RELEASES ONE WAVE. Returns how many animals it actually put on the ground, which is never assumed
-- -- `spawnSounder` can refuse, and a wave that silently released nothing is a playtest with no
-- action in it and no line saying why.
function ForestTest.release(now: number): (number, string)
	local spec = ForestTest.waveAt(state.waveIndex + 1)
	local runtime = state.runtime
	if runtime == nil then
		-- A WAVE SLOT IS NOT BURNED BY A WORLD THAT CANNOT SPAWN (task 122 round 2). The counter used
		-- to advance above this line, so a nil runtime walked the cycle forward and the wave that
		-- WOULD have been released never happened at all -- the first real wave came out as number
		-- two, with number one's composition skipped.
		return 0, "no runtime"
	end
	state.waveIndex += 1
	-- THE CAP IS CHECKED BEFORE THE SPAWN, not after, and it is the SMALLER of two caps.
	--
	-- Karen asked for *"a lot not too much to break"*, which is `Data.MAX_BOARS`. The runtime has
	-- its own ceiling as well (`maxBoars`), and `Runtime:spawn` ASSERTS rather than refusing when it
	-- is reached -- so asking past it is not a declined wave, it is an error that kills the
	-- heartbeat this runs on.
	local ceiling = math.min(Data.MAX_BOARS, runtime:capacity())
	local room = ceiling - runtime:count()
	if room <= 0 then
		return 0, string.format("wave %d held: %d of %d boars already out", state.waveIndex, runtime:count(), ceiling)
	end
	-- WHO IS IN THIS FLOCK (task 123 round 8). Karen: *"they move in floks meaning 2 feamles 3 males
	-- and kids / 2 males or 5 males and 3 famales ect"*. `spec.composition` indexes
	-- `Boar.CONFIG.SOUNDER.COMPOSITIONS`, because who is in a flock is the boar system's fact and
	-- which flock comes next is the drive's. A composition carries its own size.
	local composition = boarConfig().SOUNDER.COMPOSITIONS[spec.composition]
	local wanted = if composition then Boar.compositionSize(composition) else (spec.size or 1)
	local size = math.min(wanted, room)
	-- ...AND IF THERE IS NOT ROOM FOR THE WHOLE FLOCK the SHAPE is dropped rather than quietly
	-- half-filled: "five males and three females" arriving as three animals of whichever kind the
	-- loop reached first is not the flock she asked for.
	if composition ~= nil and size < wanted then
		composition = nil
	end
	-- AIMED AT THE STAND SHE LOCKED, not at a fixed point on the map (task 123 round 8). Karen:
	-- *"also they has to cross close to me also"*. Stands are 150 studs apart, so a wave released at
	-- a fixed x could be 300 studs from the one she picked -- which is why "close" was luck before.
	local standX = ForestTest.hunterStandX()
	local centre = Data.wavePoint(standX, spec)
	-- WHAT THESE TWO ACTUALLY RETURN, read off `Boar` rather than assumed -- the first version of
	-- this line assumed both gave a count and crashed the whole schedule on the first wave with
	-- "attempt to compare number < table", so NO wave ever ran:
	--   `Runtime:spawnSounder` returns a TABLE of handles -- `{}` when it refuses, one handle when
	--     the size is 1, otherwise one per member. Its length is the count.
	--   `Runtime:spawn` returns a HANDLE, which is truthy and is not a number.
	-- THE HANDLES ARE KEPT, because the beater follows the herd and a herd is its members.
	-- HOW MANY ANIMALS ARRIVE ALREADY RUNNING, counted across the spawn (task 123 round 3). The
	-- SHOT clause lives in `Runtime:spawn` -- it remembers the bang for `PACE.SPOOK_MEMORY_SECONDS`
	-- and hands it to whatever it creates -- so this is the only place the drive can SEE it happen,
	-- and Karen's console is where "the next flock came in running" has to be visible.
	local spookedBefore = runtime:stats().spawnedSpooked
	local handles = {}
	if size <= 1 then
		local handle = runtime:spawn(centre, "male")
		if handle ~= nil then
			table.insert(handles, handle)
		end
	else
		-- 90 AND NOT 30 (task 123 round 2): `Runtime:spawnSounder` now sizes its ring to the group
		-- (`SOUNDER.SPAWN_SPACING`) and then clamps it inside this, so a sounder of 25 needs ~26
		-- studs of radius to not spawn inside itself. There is no pad to stay on in this world --
		-- `world.groundAt` raycasts the real terrain for every member.
		handles = runtime:spawnSounder(centre, size, 90, composition)
	end
	local placed = #handles
	-- A WAVE RELEASED NEXT TO A BEATER THAT WAS ALREADY WORKING ARRIVES RUNNING (task 123 round 3).
	-- Karen: *"next flot comes without spook if there wasant driver or shoot withing 5s otherwise
	-- running"*. The SHOT half lives in `Runtime:spawn` (it remembers the bang for
	-- `PACE.SPOOK_MEMORY_SECONDS`); the DRIVER half is this, because only the drive knows where its
	-- own beaters are -- and the beater belonging to THIS wave does not exist yet, which is what
	-- makes "was there a driver here already" a question with a meaning.
	local notice = boarConfig().SENSE.NOTICE_MOVING
	local spookedBy = nil
	for _, threat in ipairs(ForestTest.boarThreats(now)) do
		local away = Vector3.new(threat.position.X - centre.X, 0, threat.position.Z - centre.Z)
		if threat.kind == "driver" and away.Magnitude <= notice then
			spookedBy = threat.id
		end
	end
	if spookedBy ~= nil then
		for _, handle in ipairs(handles) do
			runtime:spook(handle.id, centre)
		end
	end
	if placed > 0 then
		table.insert(state.active, {
			centre = centre,
			handles = handles,
			at = now,
			turnsBack = spec.turnsBack == true,
			-- THE PASS ACROSS HER FRONT (task 123 round 8), and where it began measuring from:
			-- `lateralFromX` is latched by `ForestTest.lateralTravel` the first time the herd reaches
			-- the band, so the span is measured from where the walk STARTED.
			lateral = spec.lateral,
			lateralFromX = nil :: number?,
			id = string.format("beater-%d", state.waveIndex),
		})
		state.released += placed
	end
	local bornRunning = runtime:stats().spawnedSpooked - spookedBefore
	local how = ""
	if spookedBy ~= nil then
		how = string.format(" (RUNNING: %s was already pushing here)", spookedBy)
	elseif bornRunning > 0 then
		how = string.format(
			" (RUNNING: %d of them heard a shot in the last %ds)",
			bornRunning,
			boarConfig().PACE.SPOOK_MEMORY_SECONDS
		)
	end
	return placed,
		-- `spec.holding` IS GONE (task 123 round 9, and it was my own round-8 breakage): round 8
		-- removed the named holdings and this line still formatted one, so every single release
		-- raised "invalid argument #3 to 'format' (string expected, got nil)" and the schedule died
		-- inside `step`. The wave is described by what it now HAS -- where it was aimed, relative to
		-- the hunter's stand, and what was in it.
		string.format(
			"wave %d: %+d studs from the stand, %d animal(s) -- %s%s",
			state.waveIndex,
			spec.offsetX or 0,
			placed,
			spec.note,
			how
		)
end

-- Drops waves whose beater has gone, and waves with nothing left to push. The wave's surviving
-- animals stay; only the push is over.
function ForestTest.retire(now: number)
	for index = #state.active, 1, -1 do
		local wave = state.active[index]
		local centre = ForestTest.herdCentre(wave.handles)
		local dz = if centre then centre.Z - Data.roadZ(centre.X) else nil
		local gone = ForestTest.wavePhase(
			now - wave.at,
			wave.turnsBack,
			dz,
			wave.lateral,
			if centre then ForestTest.lateralTravel(wave, centre, dz :: number) else nil
		) == "done"
		if gone or centre == nil then
			table.remove(state.active, index)
		end
	end
end

-- ---------------------------------------------------------------- the hunter's stand

function ForestTest.pickOf(userId: number)
	return state.picks[userId]
end

-- Opens the 10-second window. Nothing is locked yet: where he walks IS the choice.
function ForestTest.openPick(userId: number, now: number)
	state.picks[userId] = { index = Data.PICK.defaultIndex, lockedAt = nil, openedAt = now } :: any
end

-- Locks whatever he is nearest to. Called by the timer, or early when he confirms.
function ForestTest.lockPick(userId: number, position: Vector3, now: number): number
	local pick = state.picks[userId]
	if pick == nil then
		ForestTest.openPick(userId, now)
		pick = state.picks[userId]
	end
	if (pick :: any).lockedAt == nil then
		pick.index = ForestTest.nearestStand(position);
		(pick :: any).lockedAt = now
	end
	return pick.index
end

function ForestTest.clearPick(userId: number)
	state.picks[userId] = nil
end

-- PULLS A LOCKED HUNTER BACK INSIDE HIS LEASH. Returns the position it moved him to, or nil.
--
-- IT PULLS, IT DOES NOT FREEZE. Karen: *"he can move few steps on each side max"* -- and *"I want
-- tomorrow to test shooting and walking"*, so anchoring the character would break the thing she is
-- testing. Walking out simply stops being possible at six studs.
function ForestTest.leash(userId: number, root: BasePart): Vector3?
	local pick = state.picks[userId]
	if pick == nil or (pick :: any).lockedAt == nil then
		return nil
	end
	if ForestTest.withinLeash(root.Position, pick.index) then
		return nil
	end
	local home = Data.standPosition(pick.index)
	local flat = Vector3.new(root.Position.X - home.X, 0, root.Position.Z - home.Z)
	local pulled = home + flat.Unit * Data.PICK.leashStuds
	local to = Vector3.new(pulled.X, root.Position.Y, pulled.Z)
	root.CFrame = CFrame.new(to) * (root.CFrame - root.CFrame.Position)
	return to
end

-- ---------------------------------------------------------------- the loop

function ForestTest.start(runtime, now: number)
	state.runtime = runtime
	state.started = true
	state.startedAt = now
	state.nextWaveAt = now + Data.SCHEDULE.intervalSeconds
	state.waveIndex = 0
	state.released = 0
	state.active = {}
	-- TASK 127: the live lines, their own Random, and the stuck counter the proof reads.
	state.lines = {}
	state.rng = Random.new()
	state.stuck = 0
end

-- ONE TICK. Returns a line when something happened and nil otherwise, so the boot script can print
-- the drive's own account of itself rather than guessing at it.
-- WHAT EACH LIVE WAVE IS DOING, as one line per wave. It exists because "the beater had no visible
-- effect" is the kind of claim that needs a number beside it: where the herd is, where its beater
-- is, and how far apart they are against `SENSE.FLUSH_STUDS`.
function ForestTest.waveReport(now: number): { string }
	local out = {}
	for _, wave in ipairs(state.active) do
		local centre = ForestTest.herdShape(wave.handles)
		if centre ~= nil then
			local elapsed = now - wave.at
			local dz = (centre :: Vector3).Z - Data.roadZ((centre :: Vector3).X)
			local at = ForestTest.beaterPosition(
				centre :: Vector3,
				elapsed,
				wave.turnsBack,
				dz,
				wave.lateral,
				ForestTest.lateralTravel(wave, centre :: Vector3, dz)
			)
			local alive = 0
			for _, handle in ipairs(wave.handles) do
				if handle and handle.part and handle.part.Parent then
					alive += 1
				end
			end
			table.insert(
				out,
				string.format(
					"%s %s t=%.0fs alive=%d herd dz=%.0f beater %s",
					wave.id,
					ForestTest.wavePhase(elapsed, wave.turnsBack, dz),
					elapsed,
					alive,
					dz,
					if at
						then string.format("dz=%.0f gap=%.1f", at.Z - Data.roadZ(at.X), (at - centre).Magnitude)
						else "none"
				)
			)
		end
	end
	return out
end

function ForestTest.step(now: number): string?
	if not state.started then
		return nil
	end
	-- ONE SIDE TO THE OTHER, IN A LINE (task 127). With `LINE.enabled` the drive does ONE thing:
	-- release a line and walk it across. The pushes, the turn-backs, the lateral passes and the
	-- phantom beaters below are untouched and come back with one word, because Karen has accepted
	-- parts of them before.
	if Data.LINE ~= nil and Data.LINE.enabled == true then
		ForestTest.stepLines(now)
		if now < state.nextWaveAt then
			return nil
		end
		state.nextWaveAt = now + Data.SCHEDULE.intervalSeconds
		state.waveIndex += 1
		return ForestTest.releaseLine(now)
	end

	ForestTest.retire(now)
	ForestTest.urgeAcrossRoad()
	ForestTest.checkAtTheEdge()
	if now < state.nextWaveAt then
		return nil
	end
	state.nextWaveAt = now + Data.SCHEDULE.intervalSeconds
	local _placed, line = ForestTest.release(now)
	return line
end

-- ASKS EVERY WAVE THAT IS NEAR THE ROAD FOR A TROT (task 123 round 4). Karen: *"they can trot when
-- crossing"*. Re-asked every step rather than latched, because `Brain:urge` takes SECONDS and a wave
-- that turns back should go straight back to a walk -- so the urgency has to expire by itself.
--
-- THE DRIVE OWNS THIS AND THE BRAIN DOES NOT: where the road is is this world's fact, and `Brain`
-- has never heard of a road. All it is told is "for the next second, a trot is fine".
function ForestTest.urgeAcrossRoad()
	local runtime = state.runtime
	if runtime == nil then
		return
	end
	local wave = ForestTest.WAVE
	-- EVERY ANIMAL NEAR THE ROAD, not every animal in an ACTIVE WAVE. MEASURED: two crossings at
	-- 4.0 studs/s -- a walk -- because their wave's push had already retired (`WAVE.pushSeconds`),
	-- so `state.active` no longer held them and nothing asked them for a trot. A straggler crossing
	-- the road is exactly as much "crossing" as the rest of its herd was, and it is the one a hunter
	-- is still watching. Reading each animal's own position is also simpler than the herd centroid
	-- it replaced: no wave, no centroid, no empty-handle case.
	for _, handle in ipairs(runtime:boars()) do
		local at = handle.position()
		local dz = at.Z - Data.roadZ(at.X)
		if dz <= wave.crossTrotDz and dz >= -wave.crossTrotPastDz then
			runtime:urge(handle.id, 1)
		end
	end
end

-- STOPPING AT THE EDGE OF THE OPEN (task 126). Karen: *"so they comming we can hear them as now is
-- / then they can stop before entering the road"*.
--
-- THE SAME SHAPE AS `urgeAcrossRoad` ABOVE, AND FOR THE SAME REASON: where the road is is this
-- world's fact and `Brain` has never heard of a road, so all the animal is told is "you are at the
-- edge of the open now". Whether it stops, for how long, and whether it has already had its look are
-- the Brain's (`Brain:check` -- a chance, a duration, and one check per approach).
--
-- ONLY THE ANIMAL AT THE FRONT IS ASKED, because a file that stops at the edge is one animal
-- stopping and eight closing up behind it -- which is what the file already does for free, since
-- every follower steers at a point behind the one ahead. Asking all nine would be nine animals each
-- deciding separately to stop, which is a traffic jam and not a sounder.
function ForestTest.checkAtTheEdge()
	local runtime = state.runtime
	if runtime == nil then
		return
	end
	local wave = ForestTest.WAVE
	-- The band is OUTSIDE the road and north of it: from the road's near verge out to `edgeDz`.
	for _, handle in ipairs(runtime:boars()) do
		local at = handle.position()
		local dz = at.Z - Data.roadZ(at.X)
		if dz > wave.edgeNearDz and dz <= wave.edgeFarDz and runtime:leads(handle.id) then
			runtime:check(handle.id)
		end
	end
end

-- ======================================================================= THE LINE (task 127)
--
-- Karen: *"imagine they come from one side in one line and crossing road thats it"*, and *"it's
-- simple"*. One route, computed once; one leader walking it; everybody else walking HER TRAIL.
--
-- WHY THE DRIVE OWNS THIS AND NOT THE BOAR. The route is a fact about this world -- where the road
-- is, where the hunter is standing, where the exit is -- and `Boar` has never heard of a road. The
-- Brain's job is unchanged and is one sentence: walk to the point you were given at the speed you
-- were given (`Brain:leadTo`). Everything below decides WHICH point.

-- WHICH PACE THIS WAVE TRAVELS AT. Pure: a roll in, a pace name out, drawn from `LINE.paceMix`'s
-- weights -- *"then trot sometimes walk sometimes run"*.
function ForestTest.paceFor(roll: number, mix): string
	local total = 0
	for _, row in ipairs(mix) do
		total += row.weight
	end
	local want = math.clamp(roll, 0, 0.999999) * total
	local seen = 0
	for _, row in ipairs(mix) do
		seen += row.weight
		if want < seen then
			return row.pace
		end
	end
	return mix[#mix].pace
end

-- ...and what that pace is in studs per second, in the BOAR's own numbers rather than new ones.
function ForestTest.paceSpeed(pace: string, config): number
	local boarPace = config.PACE
	if pace == "run" then
		return boarPace.RUN_SPEED
	elseif pace == "walk" then
		return boarPace.WALK_SPEED
	end
	return boarPace.TROT_SPEED
end

-- THE ROUTE, COMPUTED ONCE (task 127). Spawn -> a crossing point on the road -> the exit, far south.
--
-- `PathfindingService` AND NOT A STRAIGHT LINE, and that is the whole answer to *"some boars stuck in
-- tree"*: the agent is sized to the animal, the trunks are `CanCollide` so the mesh treats them as
-- obstacles, and the route therefore goes ROUND them before anybody walks it. The leader never
-- steers by whiskers in this mode -- there is nothing left for a whisker to find.
--
-- TWO LEGS, NOT ONE. A single path from the forest to the exit would be free to cross the road
-- wherever it liked; this one is pinned through the crossing point the drive chose, which is what
-- makes "it crosses in front of the hunter" true rather than lucky.
function ForestTest.computeRoute(from: Vector3, crossing: Vector3, exit_: Vector3): { Vector3 }?
	local path = PathfindingService:CreatePath({
		-- The boar's own half-width plus a margin: `Boar.CONFIG.BODY_SIZE` is 2 wide, so 1 is the
		-- half-width and 2.5 leaves a body's worth of clearance past a trunk.
		--
		-- AND THE ROUTE IS NOT WHAT TOUCHES THE TREES (round 3), which was worth knowing before
		-- widening anything. 4 was tried, and the measured trunk contacts did not move (16 distinct
		-- pairs, 11 of them leaders, against 12 and 6 at 2.5 -- inside the run-to-run spread). Then
		-- the navmesh itself was asked, in the Edit place: a path computed straight through a trunk
		-- of radius 0.9 came back Success with its nearest waypoint 3.9 studs from the trunk's
		-- centre, so the mesh DOES see the trunks and DOES hold the requested clearance. A leader
		-- who still touches one is therefore not following this route at that moment -- she is
		-- spooked and running straight (`MOVE.FLIGHT`), which is what Karen asked for, or she is
		-- sliding through a turn. That is where the remaining contacts live.
		AgentRadius = 2.5,
		AgentHeight = 4,
		AgentCanJump = false,
		AgentCanClimb = false,
		WaypointSpacing = 8,
	})
	local points = {}
	for _, leg in ipairs({ { from, crossing }, { crossing, exit_ } }) do
		local ok = pcall(function()
			path:ComputeAsync(leg[1], leg[2])
		end)
		if not ok or path.Status ~= Enum.PathStatus.Success then
			return nil
		end
		for index, waypoint in ipairs(path:GetWaypoints()) do
			-- The first waypoint of a leg is where the leg starts, which is the previous leg's last.
			if index > 1 or #points == 0 then
				table.insert(points, waypoint.Position)
			end
		end
	end
	if #points < 2 then
		return nil
	end
	return ForestTest.clearRoute(points)
end

-- EVERY SEGMENT SWEPT WITH THE ANIMAL'S OWN BODY, and a detour inserted where it clips (task 127
-- round 2, the Director's item 1a).
--
-- WHY THE NAVMESH IS NOT ENOUGH: `PathfindingService` guarantees the WAYPOINTS are reachable for an
-- agent of the given radius, not that the straight line between two of them is clear -- and
-- `WaypointSpacing` is 8 studs, so a trunk can sit inside a span the animal is about to walk in a
-- straight line. The measured symptom was 16-41 distinct (boar, trunk) contact pairs.
--
-- `Blockcast` IS THE RIGHT CAST: a box the size of the body, swept along the segment, which is what
-- the animal actually is -- a raycast down the centreline would miss a trunk its shoulder hits.
--   https://create.roblox.com/docs/reference/engine/classes/WorldRoot#Blockcast
function ForestTest.clearRoute(points: { Vector3 }): { Vector3 }
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Workspace:FindFirstChild("Boars") :: any, Workspace.Terrain }
	params.IgnoreWater = true
	-- The boar's own box, a little proud of it: `Boar.CONFIG.BODY_SIZE` is 2 wide and 3 tall.
	local body = Vector3.new(3, 3, 1)
	local out = { points[1] }
	for index = 2, #points do
		local from, to = points[index - 1], points[index]
		local span = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
		local length = span.Magnitude
		if length > 1e-3 then
			local direction = span.Unit
			local start = CFrame.lookAt(from + Vector3.new(0, 1.5, 0), from + direction + Vector3.new(0, 1.5, 0))
			local hit = Workspace:Blockcast(start, body, direction * length, params)
			if hit ~= nil then
				-- SIDESTEP THE MIDPOINT, both ways, and keep the first side that is clear. One
				-- insertion per segment: this is a nudge round a trunk the navmesh allowed, not a
				-- second pathfinder.
				local side = Vector3.new(direction.Z, 0, -direction.X)
				local middle = from:Lerp(to, 0.5)
				for _, offset in ipairs({ 4, -4, 7, -7 }) do
					local detour = middle + side * offset
					local a = CFrame.lookAt(from + Vector3.new(0, 1.5, 0), detour + Vector3.new(0, 1.5, 0))
					local toDetour = Vector3.new(detour.X - from.X, 0, detour.Z - from.Z)
					local b = CFrame.lookAt(detour + Vector3.new(0, 1.5, 0), to + Vector3.new(0, 1.5, 0))
					local toEnd = Vector3.new(to.X - detour.X, 0, to.Z - detour.Z)
					if
						Workspace:Blockcast(a, body, toDetour, params) == nil
						and Workspace:Blockcast(b, body, toEnd, params) == nil
					then
						table.insert(out, Vector3.new(detour.X, middle.Y, detour.Z))
						break
					end
				end
			end
		end
		table.insert(out, to)
	end
	return out
end

-- RELEASES ONE WAVE AS A LINE. Returns the log line, or nil when nothing could be placed.
function ForestTest.releaseLine(now: number): string?
	local runtime = state.runtime
	if runtime == nil then
		return nil
	end
	local boar = boarConfig()
	local lineData = Data.LINE
	local rng = state.rng
	local standX = ForestTest.hunterStandX()

	-- WHERE IT CROSSES, and it is relative to the stand she locked (task 123 round 8): stands are
	-- 150 studs apart, so a fixed x would be luck.
	local offset = lineData.crossOffsets[rng:NextInteger(1, #lineData.crossOffsets)]
	local crossX = standX + offset
	local crossing = Vector3.new(crossX, Data.CENTRE.Y, Data.roadZ(crossX))
	local startZ = crossing.Z + lineData.spawnNorthStuds
	local start = Vector3.new(crossX, Data.groundAt(crossX, startZ) or Data.CENTRE.Y, startZ)
	-- PAST THE DESPAWN LINE, NOT UP TO IT, and that was a measured bug: the route ended at
	-- `EXIT_Z + 20`, which is twenty studs NORTH of the line `Brain:_outcome` despawns at -- so every
	-- line walked its whole route, arrived, and then stood on the last waypoint for ever. The stuck
	-- counter showed it as a cluster of animals all going still at 134-152 s, which is exactly how
	-- long a 600-stud route takes. Ending ten studs PAST the line means the last thing they do is
	-- cross it, which is Karen's *"once they in another side of road they run away"*.
	local exitPoint = Vector3.new(crossX, Data.CENTRE.Y, Data.EXIT_Z - 10)

	local count = rng:NextInteger(4, 9)
	local lines = if rng:NextNumber() < lineData.twoLineChance then 2 else 1
	local pace = ForestTest.paceFor(rng:NextNumber(), lineData.paceMix)
	local speed = ForestTest.paceSpeed(pace, boar)

	-- THE ROUTES FIRST, BEFORE A SINGLE ANIMAL EXISTS, and that ordering is the whole of a bug this
	-- round paid for. MEASURED: `releaseLine` reported `placed=9 routes made=0` every wave, while the
	-- same call from a bare console answered `Success, 32 waypoints`. The difference was the nine
	-- boars: they are `CanCollide`, they had just been spawned ON the start point, and
	-- `ComputeAsync` from inside a pile of colliders fails. Computing first also means a wave whose
	-- route cannot be found never spawns anything, instead of leaving nine loose animals behind.
	-- ONLY THE LINES THAT HAVE A ROUTE ARE RELEASED (task 122 round 2). With two lines and one
	-- route, every animal used to be spawned and the group whose route was missing was led by
	-- nobody, retired by nothing, and counted against `maxBoars` until it happened to wander past
	-- `exitZ`. A line that cannot be walked is a line that is not released.
	--
	-- EACH SURVIVOR KEEPS ITS OWN LATERAL OFFSET, so the animals are spawned on the route that was
	-- actually computed rather than on the one its index would have had.
	local routes = {}
	for which = 1, lines do
		local lateral = (which - 1 - (lines - 1) / 2) * lineData.lineGapStuds
		local route = ForestTest.computeRoute(
			start + Vector3.new(lateral, 0, 0),
			crossing + Vector3.new(lateral, 0, 0),
			exitPoint + Vector3.new(lateral, 0, 0)
		)
		if route ~= nil then
			table.insert(routes, { route = route, lateral = lateral })
		end
	end
	if #routes == 0 then
		return nil
	end
	local asked = lines
	lines = #routes

	-- THE ANIMALS, spawned one at a time ALONG the approach so they are already a file. Not
	-- `spawnSounder`: that places a RING, which is the spread Karen is complaining about.
	local toward = Vector3.new(0, 0, -1) -- the road is south of the spawn
	local members = {}
	-- THE WORLD'S CONFIG, AND REAL ROLLS (task 122 round 2, the Reviewer's blocking finding). Asking
	-- `Boar.CONFIG` asks the MODULE, whose `KINDS.ENABLED` follows the `BOAR_MODEL` flag and is off
	-- by default -- so every animal in every line came out "male", `Line.order`'s rank table saw one
	-- rank for all of them, and the sow-led file this mode exists for could not happen. The runtime
	-- holds what this world was actually built with (`Runtime:config`). The rolls were `{}` as well,
	-- which made `(rolls[index] or 1) < YOUNG_MALE_CHANCE` false for ever: a line of sow plus
	-- piglets and never a young male.
	local rolls = {}
	for index = 1, count do
		rolls[index] = rng:NextNumber()
	end
	local kinds = Boar.sounderKinds(count, rolls, boar, nil)

	-- THE MARCHING ORDER IS DECIDED BEFORE ANYBODY IS PLACED, AND THE FILE IS LAID OUT BEHIND ITS
	-- LEADER (task 127 round 2, the Reviewer's blocking finding -- and it is why the line never
	-- formed).
	--
	-- It used to spawn along the direction of TRAVEL and order afterwards: spawn index 1 stood at
	-- `start` and every later index stood further SOUTH, further along the route -- while
	-- `Line.order` made the sow (index 1) the LEADER. So the leader was the REARMOST animal on the
	-- ground and every follower was already past the head of her trail: `Line.arcAt` clamped each of
	-- them to that head, `slack = stationS - ownS` came out negative for all of them, and the
	-- "a follower that has overrun waits" rule froze the whole line while the sow walked through it.
	-- For a wave of nine the tail animal needed her to walk ~135 studs of a 180-stud approach before
	-- its station even reached it.
	--
	-- Now the kinds are ordered and dealt FIRST, and rank k is placed `(k - 1) * spacing` studs
	-- BEHIND the head -- `start - toward * ...`, which is north, the side the drive comes from --
	-- which is exactly where the seeded trail puts station k. Every follower starts ON its station
	-- and the line is a line from the first step.
	local order = {}
	for index = 1, count do
		table.insert(order, { kind = kinds[index] })
	end
	local plans = Line.split(Line.order(order), lines)

	local groups = {}
	for which, plan in ipairs(plans) do
		groups[which] = {}
		local lateral = routes[which].lateral
		for rank, member in ipairs(plan) do
			local at = start - toward * ((rank - 1) * lineData.spacingStuds) + Vector3.new(lateral, 0, 0)
			local ground = Data.groundAt(at.X, at.Z)
			local handle = runtime:spawn(Vector3.new(at.X, (ground or Data.CENTRE.Y) + 2, at.Z), member.kind)
			if handle ~= nil then
				local row = { id = handle.id, kind = member.kind }
				table.insert(groups[which], row)
				table.insert(members, row)
			end
		end
	end
	if #members == 0 then
		return nil
	end
	local made = 0
	for which, group in ipairs(groups) do
		if #group > 0 then
			local route = routes[which].route
			-- THE TRAIL IS SEEDED WITH THE LINE ITSELF, and that is a measured fix rather than a
			-- tidy-up. `Line.pointBack` answers nil until the leader has walked as far as the
			-- station being asked for, so with an empty trail every follower was told "walk at
			-- the leader" for the first few seconds -- they bunched onto her and then strung out
			-- behind, and the measured nose-to-nose gap came out at a 9.6 median against a
			-- `spacingStuds` of 3. Seeding with the points the followers are ALREADY STANDING ON
			-- -- behind her, along the approach -- means station k exists on the very first step
			-- and the line is formed from the moment it is released.
			-- ON THE LINE'S OWN AXIS, NOT THE CENTRELINE (task 127 round 3, the Reviewer's finding).
			-- The bodies carry `+ lateral` and so does the route, and the seed did not -- so a
			-- two-line wave gave BOTH files the same seeded polyline down the middle, 2.5 studs from
			-- where either of them stood. Followers are ordered to points on that polyline while
			-- their stations are still inside the seed, so the two files were pulled together into
			-- exactly the body overlap `spacingStuds` exists to prevent, and the seam between the
			-- seed and the leader's real crumbs had a 2.5-stud jog in it. It bit a ONE-line wave too
			-- whenever the route that survived was not the first.
			local seeded = {}
			local origin = start + Vector3.new(routes[which].lateral, 0, 0)
			for back = math.ceil((#group + 1) * lineData.spacingStuds), 0, -1 do
				table.insert(seeded, { at = origin - toward * back, s = 0 })
			end
			for index = 2, #seeded do
				seeded[index].s = seeded[index - 1].s
					+ (Vector3.new(
						seeded[index].at.X - seeded[index - 1].at.X,
						0,
						seeded[index].at.Z - seeded[index - 1].at.Z
					)).Magnitude
			end
			-- A LINE IS A PACK FOR THE EARS TOO (task 139). Without this its members have no
			-- `sounderId` and `Boar.hasVoice` lets every one of them speak -- see
			-- `Runtime:formSounder`.
			local pack = {}
			for _, member in ipairs(group) do
				table.insert(pack, member.id)
			end
			runtime:formSounder(pack)
			table.insert(state.lines, {
				id = string.format("line-%d-%d", state.waveIndex, which),
				members = group,
				route = route,
				leg = 1,
				trail = seeded,
				speed = speed,
				-- The pace this wave was drawn at, kept so the sow's "wait for the tail" slow-down
				-- eases back to it rather than to whatever she was doing a moment ago.
				baseSpeed = speed,
				pace = pace,
				bornAt = now,
				crossing = crossing,
				crossed = false,
				checked = false,
				stuckFrom = {},
				stuckAt = {},
				repaths = 0,
			})
			made += #group
		end
	end
	if made == 0 then
		return nil
	end
	state.released += made
	return string.format(
		-- MADE *OF SPAWNED*, because the two can only differ if an animal was left behind by a line
		-- that was not released -- which is the orphan the Reviewer found and this round closed. A
		-- wave that reads "5 of 5 animal(s) in 1 of 2 line(s)" is the case: one route failed, one
		-- line was released, and nobody was spawned for the line that could not be walked.
		"line %d: %d of %d animal(s) in %d of %d line(s) at a %s, crossing %+d studs from the stand",
		state.waveIndex,
		made,
		#members,
		lines,
		asked,
		pace,
		offset
	)
end

-- ONE STEP OF EVERY LIVE LINE. The leader walks her route; everybody else rides her trail.
function ForestTest.stepLines(now: number)
	local runtime = state.runtime
	if runtime == nil then
		return
	end
	local lineData = Data.LINE
	for index = #state.lines, 1, -1 do
		local line = state.lines[index]
		-- DEAD AND GONE MEMBERS DROP OUT, and the line closes up behind them: a shot animal must not
		-- leave a hole its followers keep station on.
		-- ...AND SO HAS ONE THAT HAS FLED OR CROSSED: IT HAS LEFT THE DRIVE FOR GOOD (task 139, the
		-- Director's decision A, and Karen's own model -- *"they don't come back from that side ...
		-- once they in another side of road they run away"*).
		--
		-- THE REJOIN RULE WAS THE REGRESSION. Task 136 sent an animal whose flight had ended back to
		-- the TAIL of its line -- and the tail is NORTH of the road, so with the flight now pointed
		-- south (`Brain:_latchFlight`) every fled animal was ordered straight back into the view it
		-- had just left: MEASURED in round 1 at 19 to 26 animals coming back north, against 0 on
		-- main. The same mechanism is the "stands and stays" Karen saw -- the line takes a shot
		-- animal back, hands it the tail station, and the overrun rule orders `point = here,
		-- speed = 0`, which is a wounded boar standing perfectly still in the open.
		--
		-- SO IT IS ONE RULE AND IT IS PERMANENT, and `line.gone` remembers it. Flying, hurt, or south
		-- of the road: out of the file, never ordered again, never rejoined. What it does next is
		-- `Brain`'s business -- the flight, the cripple, the bleed-out -- and none of this file's.
		-- The rejoin path is deleted; `backups/2026-10-09-line-rejoin-at-tail.md` keeps it.
		line.gone = line.gone or {}
		local live = {}
		for _, member in ipairs(line.members) do
			local status = runtime:statusOf(member.id)
			if status ~= nil and status.alive then
				local wound = runtime:woundOf(member.id)
				local out = line.gone[member.id] == true
					or runtime:flying(member.id)
					or (wound ~= nil and wound.severity ~= nil and wound.severity ~= "healthy")
					or status.position.Z < Data.roadZ(status.position.X) - Data.ROAD.halfWidthStuds
				if out then
					line.gone[member.id] = true
				else
					table.insert(live, { id = member.id, kind = member.kind, status = status })
				end
			end
		end
		line.members = {}
		for _, row in ipairs(live) do
			table.insert(line.members, { id = row.id, kind = row.kind })
		end
		if #live == 0 or now - line.bornAt > lineData.maxSeconds then
			table.remove(state.lines, index)
			continue
		end

		line.arcOf = line.arcOf or {}

		-- AN ANIMAL IN FLIGHT IS NOT IN THE LINE ANY MORE (task 126 round 2, the Reviewer's blocking
		-- finding). `Brain` now drops an order the moment a fright latches, and the drive must not
		-- hand it a new one on the next Heartbeat -- re-ordering every member every frame is what
		-- kept a shot boar walking its trail at the ordered speed instead of running straight.
		-- `Runtime:flying` asks the Brain; a frightened animal is skipped here until its flight ends,
		-- and then it rejoins the file at whatever station is free.
		line.freeUntil = line.freeUntil or {}
		local function leadIfFree(id: string, point: Vector3, speed: number)
			if runtime:flying(id) then
				return
			end
			-- ...AND A WEDGED LEADER IS LEFT ALONE FOR A MOMENT (task 136). See
			-- `LINE.leaderFreeSeconds`: while this window is open she is NOT ordered, so the Brain's
			-- own whiskers and wedge sidestep -- both gated on `not ordered` -- can free her.
			if (line.freeUntil[id] or 0) > now then
				return
			end
			runtime:leadTo(id, point, speed)
		end

		local leader = live[1]
		local at = leader.status.position
		-- THE LEADER WALKS THE ROUTE. One waypoint at a time, consumed when she is within a body
		-- length -- the same `WAYPOINT_RADIUS` idea the Brain's own route follower uses.
		while line.leg < #line.route do
			local target = line.route[line.leg]
			if (Vector3.new(target.X - at.X, 0, target.Z - at.Z)).Magnitude <= 6 then
				line.leg += 1
			else
				break
			end
		end
		local target = line.route[math.min(line.leg, #line.route)]
		leadIfFree(leader.id, target, line.speed)

		-- ...AND SHE LOOKS BEFORE SHE CROSSES (task 126 round 2). Karen: *"they can stop before
		-- entering the road"*. `checkAtTheEdge` -- the wave path's only caller of `Runtime:check` --
		-- is unreachable while `LINE.enabled` is true, so the edge stop shipped DORMANT in the one
		-- world that has it. The leader is offered the check once per line as she comes into the band
		-- north of the road; the Brain decides whether she takes it, for how long, and refuses
		-- outright if she is already frightened. The file stacks up behind her for free: every
		-- follower's station is a point on her trail, and she has stopped moving along it.
		if not line.checked and at.Z - Data.roadZ(at.X) <= lineData.checkWithinStuds then
			line.checked = true
			runtime:check(leader.id)
		end
		line.baseSpeed = line.baseSpeed or line.speed

		-- ...AND DROPS A BREADCRUMB BEHIND HER.
		Line.addCrumb(line.trail, at, lineData.crumbStuds)
		Line.trim(line.trail, (#live + 2) * lineData.spacingStuds + 20)

		-- EVERYBODY ELSE WALKS THE TRAIL. Not AT its station -- ALONG the polyline toward it.
		--
		-- THE DIFFERENCE IS THE WHOLE OF ROUND 2 (task 127). Ordering a follower straight at a station
		-- that is round a corner orders it to CUT that corner, through whatever the leader had gone
		-- round -- which is a trunk. Measured before this change: 16-41 distinct (boar, trunk) contact
		-- pairs and a 12.7-14.1 stud median gap against an 8.5 station. Now each follower is told
		-- where it is ON the trail (`Line.arcAt`), and ordered to a point a short way FURTHER ALONG it
		-- (`Line.pointAt`), so the thing it walks is the leader's own path.
		local tailLag = 0
		-- WHERE THE ONE IN FRONT IS, ON THE TRAIL. The leader is at the head of it by construction;
		-- each follower then carries its own arc position down to the next rank, so "no follower ever
		-- ahead of the one in front" is enforced against a measured position rather than assumed from
		-- the stations.
		-- The leader is at the head of it by construction, and that is also the right bound when SHE
		-- is the one flying: the head of the trail is the furthest anything may aim either way.
		local aheadS = Line.length(line.trail)
		for rank = 2, #live do
			local follower = live[rank]
			local here = follower.status.position
			local stationS = Line.length(line.trail) - (rank - 1) * lineData.spacingStuds
			if stationS < line.trail[1].s then
				-- The line is still forming behind the seed: hold the back of the trail.
				stationS = line.trail[1].s
			end
			-- FROM WHERE IT WAS LAST STEP (task 136): see `Line.arcAt`. Without the hint a follower
			-- standing beside a loop the leader walked round a trunk reads as being on the far side
			-- of it, and is then either frozen as "overrun" or ordered straight across the loop.
			local ownS = Line.arcAt(line.trail, here, line.arcOf[follower.id], lineData.arcWindowStuds)
			line.arcOf[follower.id] = ownS
			-- SIGNED: positive means behind its station, which is the only reading that can tell
			-- "catch up" from "ease off". The euclidean distance this used to use could not.
			local slack = stationS - ownS
			if rank == #live then
				tailLag = math.max(0, slack)
			end
			-- ONE LOOKAHEAD ALONG THE TRAIL -- and it is NOT clamped to the station any more, which
			-- was the bug behind the stuck count (round 3).
			--
			-- MEASURED: 33 animals moved less than a stud in three seconds while the speed they had
			-- been ordered was above 2. They were not wedged against anything. `aim` used to be
			-- `min(ownS + lookahead, stationS)`, so a follower sitting within a lookahead of its
			-- station was handed a point UNDER ITS OWN FEET -- inside `LINE.ARRIVE_STUDS` -- and the
			-- Brain quite correctly reported it had arrived and stood there, while the line walked on
			-- and the gap opened. A follower's TARGET is a direction, and its STATION is a speed;
			-- mixing the two into one clamped point meant neither worked. The aim is now always a
			-- lookahead further along the trail (bounded only by how far the leader has walked), and
			-- the station is regulated by `Line.followerSpeed` and by the wait below, which is what
			-- they are for.
			-- WHERE IT AIMS: a lookahead along the trail, never past the one in front and never
			-- under its own feet. `Line.aimFor` is that arithmetic and its own comment is the why.
			local aim = Line.aimFor(
				ownS,
				lineData.lookaheadStuds,
				aheadS,
				lineData.noOvertakeStuds,
				lineData.minAimStuds,
				Line.length(line.trail),
				line.trail[1].s
			)
			local point = Line.pointAt(line.trail, aim)
			local speed = Line.followerSpeed(
				math.max(line.speed, leader.status.speed),
				slack,
				lineData.stationToleranceStuds,
				lineData.catchup
			)
			-- ...AND ONE THAT IS PAST ITS STATION WAITS FOR IT, rather than being walked backwards.
			--
			-- `aim` is clamped to the station, so a follower that has overrun -- the leader slows for
			-- her tail, or it closed faster than the clamp expected -- was being ordered to a point
			-- BEHIND itself at 60 % of the pace. It cannot reverse, so it shuffled on the spot, which
			-- is both the twitch visible from the stand and most of what the stuck count was
			-- counting: told to move, not moving, and right to not move. Standing still is the
			-- correct answer, and it is the same answer the sow gives when she waits (`leaderSpeed`).
			if slack < -lineData.stationToleranceStuds then
				point, speed = here, 0
			end
			leadIfFree(follower.id, point or here, speed)
			-- ...AND THE ONE IN FRONT HAS TO BE IN THE LINE (round 2, the Reviewer's note). `live` is
			-- filtered on alive, not on flying, so a bolting animal keeps its rank -- and handing its
			-- arc position down as "the one in front" regulates the file against an animal that is,
			-- two dozen lines above, declared not to be in the line any more.
			if not runtime:flying(follower.id) then
				aheadS = ownS
			end
		end

		-- ...AND THE SOW WAITS FOR HER TAIL. Karen asked for a line, and a line whose leader never
		-- looks back is a procession of singletons: measured, the gap p90 was 142-213 studs, which is
		-- a line that has broken. `Line.leaderSpeed` eases her down toward `tailSlow` of her pace once
		-- the last animal is more than `tailPatienceStuds` behind its station.
		line.speed = Line.leaderSpeed(
			line.pace == "run" and boarConfig().PACE.RUN_SPEED or line.baseSpeed,
			tailLag,
			lineData.tailPatienceStuds,
			lineData.tailSlow
		)

		-- ONCE ACROSS, THEY RUN AWAY. Karen: *"once they in another side of road they run away"*.
		if not line.crossed and at.Z < Data.roadZ(at.X) - Data.ROAD.halfWidthStuds then
			line.crossed = true
			line.speed = boarConfig().PACE.RUN_SPEED
			line.baseSpeed = boarConfig().PACE.RUN_SPEED
		end

		-- STUCK = 0, AND IT IS COUNTED. An animal that has not covered `stuckStuds` in `stuckSeconds`
		-- while it was asked to move is re-pathed (the leader) or snapped back onto the trail (a
		-- follower, by having its station handed to it directly on the next step).
		for rank, member in ipairs(live) do
			-- ONLY AN ANIMAL THAT WAS ASKED TO MOVE CAN BE STUCK (task 127 round 2). The rule in
			-- `LINE` always read "while it was asked to move" and the code tested displacement alone,
			-- so the followers this very step froze ON PURPOSE -- the overrun rule sets `speed = 0`
			-- -- were counted as stuck and then SNAPPED BACKWARDS onto a station behind them, which
			-- is the opposite of waiting. The ordered speed is published for exactly this
			-- (`Runtime:statusOf().want`), and a waiting animal's clock starts again when it moves
			-- off, so a long and legitimate wait cannot be banked against it.
			local asked = (member.status.want or 0) > lineData.stuckAskedSpeed
			if not asked then
				line.stuckFrom[member.id] = member.status.position
				line.stuckAt[member.id] = now
				continue
			end
			local was = line.stuckFrom[member.id]
			if was == nil or (now - (line.stuckAt[member.id] or 0)) >= lineData.stuckSeconds then
				if
					was ~= nil
					and (Vector3.new(member.status.position.X - was.X, 0, member.status.position.Z - was.Z)).Magnitude
						< lineData.stuckStuds
				then
					state.stuck += 1
					line.repaths += 1
					if rank == 1 then
						local route = ForestTest.computeRoute(
							member.status.position,
							line.crossing,
							Vector3.new(line.crossing.X, Data.CENTRE.Y, Data.EXIT_Z - 10)
						)
						if route ~= nil then
							line.route = route
							line.leg = 1
						end
						-- ...AND THE ROUTE ON ITS OWN IS NOT ENOUGH, which is the whole of this fix: a
						-- route computed from the spot she is wedged in can lead straight back into
						-- the trunk she is wedged against. She is let go of for a moment as well, so
						-- the Brain can do what it does for every unordered animal that meets
						-- something solid.
						line.freeUntil[member.id] = now + lineData.leaderFreeSeconds
					else
						-- A WEDGED FOLLOWER IS PUT BACK ON THE TRAIL, behind the one ahead of it. It is
						-- a teleport of a few studs onto a path the leader has already walked, which is
						-- the one place it is certainly clear -- and it is the only thing that can free
						-- an animal the solver has pinned against a trunk.
						local back = Line.length(line.trail) - (rank - 1) * lineData.spacingStuds
						local onto = Line.pointAt(line.trail, back)
						if onto ~= nil then
							runtime:placeAt(member.id, onto)
						end
					end
				end
				line.stuckFrom[member.id] = member.status.position
				line.stuckAt[member.id] = now
			end
		end
	end
end

-- Where a hunter who has not picked yet should be put: on the road, at the default stand.
function ForestTest.spawnPosition(): Vector3
	local at = Data.standPosition(Data.PICK.defaultIndex)
	-- A little above the road so the character drops onto it rather than into it.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Workspace:FindFirstChild("Boars") }
	local hit = Workspace:Raycast(at + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0), params)
	local y = if hit then hit.Position.Y else at.Y
	return Vector3.new(at.X, y + 4, at.Z)
end

-- THE ARITHMETIC IS REACHABLE ON ITS OWN, so `tests/server/forest_line.spec.luau` can drive the
-- rules a line stands on with hand-written tables instead of a running world.
ForestTest.Line = Line

return ForestTest
