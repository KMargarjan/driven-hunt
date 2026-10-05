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

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Data = require(ReplicatedStorage:WaitForChild("ForestTest"))
-- READ, NEVER WIRED: this module asks `Boar` for ONE number -- how far a boar notices a moving
-- stimulus -- so "was a driver already pushing here" uses the animal's own radius rather than a
-- second copy of it. `Boar` does not require this module, so there is no cycle.
local Boar = require(ServerScriptService:WaitForChild("Boar"))

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
	turnAtSeconds = 9, -- a `turnsBack` wave is pushed for this long before it is turned
	turnSeconds = 8,
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
	aheadStuds = 26, -- in front of the FOREMOST, to turn it
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
	turnGiveUpDz = 45, -- an AVOID takes a few seconds to swing; do not give up while it is working
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
	lateralSpan = 150, -- studs across her front: from ~95 studs one side to ~55 the other
	-- The beater stands this far off the flank, inside `SENSE.FLUSH_STUDS` (15) like `pushStuds`,
	-- because a flank beater has to flush as well as a rear one.
	lateralPushStuds = 11,
}

export type Phase = "push" | "turn" | "lateral" | "done"

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
function ForestTest.beaterPosition(
	centre: Vector3,
	rear: Vector3,
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
	if phase == "turn" then
		return rear + Vector3.new(0, 0, -wave.aheadStuds)
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
}

function ForestTest.stats()
	return {
		started = state.started,
		waves = state.waveIndex,
		released = state.released,
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
		local centre, rear = ForestTest.herdShape(wave.handles)
		if centre ~= nil then
			local dz = (centre :: Vector3).Z - Data.roadZ((centre :: Vector3).X)
			local at = ForestTest.beaterPosition(
				centre :: Vector3,
				rear :: Vector3,
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
	local index, left = ForestTest.driveIndexAt(state.startedAt or now, now, Data.DRIVE.seconds)
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
	state.waveIndex += 1
	local runtime = state.runtime
	if runtime == nil then
		return 0, "no runtime"
	end
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
	local composition = Boar.CONFIG.SOUNDER.COMPOSITIONS[spec.composition]
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
	local notice = Boar.CONFIG.SENSE.NOTICE_MOVING
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
			Boar.CONFIG.PACE.SPOOK_MEMORY_SECONDS
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
end

-- ONE TICK. Returns a line when something happened and nil otherwise, so the boot script can print
-- the drive's own account of itself rather than guessing at it.
-- WHAT EACH LIVE WAVE IS DOING, as one line per wave. It exists because "the beater had no visible
-- effect" is the kind of claim that needs a number beside it: where the herd is, where its beater
-- is, and how far apart they are against `SENSE.FLUSH_STUDS`.
function ForestTest.waveReport(now: number): { string }
	local out = {}
	for _, wave in ipairs(state.active) do
		local centre, rear = ForestTest.herdShape(wave.handles)
		if centre ~= nil then
			local elapsed = now - wave.at
			local dz = (centre :: Vector3).Z - Data.roadZ((centre :: Vector3).X)
			local at = ForestTest.beaterPosition(
				centre :: Vector3,
				rear :: Vector3,
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
	ForestTest.retire(now)
	ForestTest.urgeAcrossRoad()
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

return ForestTest
