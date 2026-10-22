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
-- THE INSTANCE AS WELL AS THE TABLE: `publishLayout` writes an attribute on the module's own
-- Rojo-owned child (`Live`), which is found through this handle and never by searching
-- `ReplicatedStorage` -- `Flags.state`'s rule, for the reason that file writes down.
local DataModule = ReplicatedStorage:WaitForChild("ForestTest")
local Data = require(DataModule)
-- READ, NEVER WIRED: this module asks `Boar` for ONE number -- how far a boar notices a moving
-- stimulus -- so "was a driver already pushing here" uses the animal's own radius rather than a
-- second copy of it. `Boar` does not require this module, so there is no cycle.
local Boar = require(ServerScriptService:WaitForChild("Boar"))

local Line = require(script.Line)
-- THE MARKER SET THIS WORLD HANDS THE DRIVE (task 157). A child module, like `Line`: it writes
-- `Workspace.ForestMarkers` and nothing else, and it requires this module back in no way at all --
-- its two ground readers are injected at the bottom of this file.
local Markers = require(script.Markers)
-- THE HIGH SEATS (task 218). The third child of this shape: it writes `Workspace.HighSeats` and
-- nothing else, it requires this module back in no way at all, and its two ground readers are
-- injected at the bottom of this file beside `Markers`'.
local Seats = require(script.Seats)
-- THE FROZEN SEAT DATA (task 221). `ForestTest.seatedStands` is the one place this layout
-- name is applied to it, so the stand DEAL and the seats `Seats.ensure` builds read one table.
local Plan = require(ReplicatedStorage:WaitForChild("HighSeats"))

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
-- ---------------------------------------------------------------- THE LIVE LAYOUT (task 179)
--
-- WHICH OF `Data.LAYOUTS` THIS DRIVE IS STANDING ON. This module is the ONE writer of that fact
-- (design 5.1): it chooses, it publishes the name for the clients, and everything else in this file
-- -- the stands, the picks, the waves, the resting wood, the beater starts -- reads it from here.
-- The client never chooses and never derives; it reads one string.
--
-- DECLARED HERE AND NOT INSIDE `state` BELOW, and the reason is Lua rather than taste: a local is
-- only an upvalue of functions defined AFTER it, and `withinStand`, `boundaryPoint` and
-- `nearestStand` all sit above `state`. Declared down there they would read a nil global.
--
-- `layout` IS NEVER NIL. It starts as the road -- which is what this world was before task 179 --
-- so a module nobody has started, or a harness query that gets a fresh copy, answers today's
-- geometry instead of indexing nil.
--
-- NAMED `chosen` AND NOT `live`, because a local called `live` already exists inside `stepLines`
-- (the animals of a file still in play) and two `live`s in one file is a reader's trap.
local chosen = {
	layout = Data.ROAD_LAYOUT :: any,
	name = Data.DEFAULT_LAYOUT,
	-- The drive number this choice belongs to, so promoting is idempotent: `Match` reads the markers
	-- once a second while `Waiting`, and only the first of those reads may deal a layout.
	--
	drive = nil :: number?,
	-- HAS THE ROTATION EVER STEPPED (task 193)? The rotation needs this and the bag did not. False
	-- means no drive has been dealt FROM THE CYCLE, so the next one is `LAYOUT_ORDER[1]` -- Karen's
	-- place 1 -- and not the name AFTER the starting one. Without it, drive 1 of every session would
	-- be her place 2, because `name` starts at the default and `nextLayout` answers the one after.
	--
	-- IT IS NOT `drive ~= nil`, and a forced drive is why: `DHForestLayout` sets `drive` without
	-- advancing the cycle, so a session that starts forced and then clears the attribute must still
	-- begin the rotation at place 1.
	-- WHERE THE CYCLE ITSELF IS, which is NOT `name` (Reviewer, round 1, note 6). `promote` writes
	-- `name` for every source, the override included, so advancing from `name` would resume the
	-- rotation from the FORCED place: force `road` at drive 3 while the cycle sat at `edge`, and
	-- drive 4 deals `edge` again. The design's section 5 item 3 says a forced drive *"resumes at
	-- exactly the next place"*, and this is the field that makes that true rather than nearly true.
	--
	-- NIL IS "THE CYCLE HAS NOT STARTED", and it needs no companion flag: `Data.nextLayout(nil)`
	-- answers `LAYOUT_ORDER[1]` by its own rule, so the first rotated drive of a session is Karen's
	-- place 1 with no branch at all. Round 2 shipped a `chosen.rotated` beside this; the Reviewer
	-- pointed out that both of its branches then had the same answer (round 2, note 2), and a flag
	-- whose two branches agree is a flag that can only ever go wrong.
	cycle = nil :: string?,
	-- "default" | "rotation" | "override" -- printed and in `stats()`, the `Flags` discipline. It is
	-- the only thing that stops a forced playtest being reported as the rotation, because
	-- `DHForestLayout` is not a `DHFlag_*` name and the harness does not refuse a run while it is
	-- set (design 11, D3).
	source = "default",
	-- WHETHER THE CLIENTS HAVE BEEN TOLD. The attribute is written once per CHOICE and not once per
	-- call, and this is what distinguishes "the name has not moved" from "the name has never been
	-- said" -- round 1 could not tell them apart and shipped a session with no map (finding 4).
	published = false,
}

-- THE LIVE LAYOUT, for every reader inside this process.
function ForestTest.layout()
	return chosen.layout
end

function ForestTest.layoutName(): string
	return chosen.name
end

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

-- ------------------------------------------------------- THE DRIVE'S RED DEER (task 239)
--
-- KAREN, 2026-10-21: *"we need all a time in drive deer"* and *"I want to see a deer"*. Task 234
-- gave the DEV drive that guarantee and proved it there; the Director measured a whole drive of the
-- PLACE SHE PLAYS on 2026-10-22 and counted cub, male and female only -- not one stag, hind or calf
-- in 80 animals. This world's waves never asked.
--
-- WHAT IS REUSED AND WHAT IS NEW, said plainly because rule 3 is one owner per system:
--   the ANIMAL's own owner answers everything about the deer -- whether there may be one
--   (`Runtime:deerAllowed`, the same `MAX_GROUPS_ALIVE` cap `spawnSounder` consults), who is in the
--   group (`Boar.deerComposition`, including `CHANCE_PER_RELEASE` for the extra ones) and how they
--   march (`Boar.MARCH_RANK`). Nothing about a deer is decided in this file.
--   the DRIVE's own owner answers WHEN, exactly as it already answers when every other wave goes.
--
-- ...AND IT IS NOT `Match.Phase.deerRelease`, WHICH IS THE OBVIOUS THING TO REUSE. That rule is
-- three clauses over a RELEASE BUDGET -- `BOARS_PER_DRIVE`, `expectedReleases` from the sounder
-- size, and "this is the last release because `boarsReleased + size >= BOARS_PER_DRIVE`". This
-- world has no budget: its drive is a 20-second metronome that runs until the clock ends the drive,
-- and `Match` releases nothing here at all (`match_phase.spec`: *"0 spawnSounder"* in the forest).
-- Every input that rule reads is absent, so sharing it would mean inventing values to feed it.
-- The two below are the same SHAPE -- one drive, one guaranteed group, drawn rather than fixed --
-- in this world's own terms.

-- HOW MANY WAVES A DRIVE OF THIS WORLD RELEASES. Pure, and it is the metronome's own arithmetic
-- rather than a number: 300 seconds at one wave per 20 is 15.
function ForestTest.wavesPerDrive(driveSeconds: number?, intervalSeconds: number?): number
	local seconds = driveSeconds or Data.DRIVE.seconds
	local gap = math.max(1, intervalSeconds or Data.SCHEDULE.intervalSeconds)
	return math.max(1, math.floor(seconds / gap))
end

-- WHICH WAVE OF A DRIVE CARRIES THE DEER. Pure: a unit draw in, an ordinal out.
--
-- IT IS DRAWN FROM THE FIRST THIRD OF THE DRIVE, AND THAT IS WHAT MAKES IT A GUARANTEE RATHER THAN
-- A BETTER CHANCE. `Match.Phase.deerRelease` draws over the whole drive and needs a third clause --
-- *"and if that ordinal is never reached, the last release carries it"* -- because its release
-- count is itself drawn. Here the ordinal is only ever reached: a 300-second drive runs 15 waves
-- and the window is five, so the deer are out inside the first 100 seconds whatever else happens.
-- It is not always wave 1 either, which a fixed "the first wave of every drive" would have been.
function ForestTest.deerWaveOf(pick: number, waves: number): number
	local window = math.max(1, math.floor(math.max(1, waves) / 3))
	return math.clamp(math.floor(math.clamp(pick, 0, 0.999999) * window) + 1, 1, window)
end

-- IS THIS WAVE THE ONE? Pure, and `>=` and not `==` on purpose: a wave that could not carry the
-- deer -- the cap said no, there was no room, the flag is off -- must not spend the drive's
-- guarantee, so the next wave picks it up. `done` is the latch, and it is set only once a group has
-- actually been placed.
function ForestTest.deerWanted(driveWave: number, deerWave: number?, done: boolean): boolean
	if done or deerWave == nil then
		return false
	end
	return driveWave >= (deerWave :: number)
end

-- IS THIS POSITION INSIDE THE STAND'S CIRCLE? Pure, so the boundary is one rule and not one rule
-- per caller. FLAT: the Y is ignored, because a hunter standing on his post is a stud above the
-- ground he picked it from and that is not leaving the stand.
--
-- IT READS THE LIVE LAYOUT, and round 1 of task 179 shipped it reading the ROAD. That was not a
-- cosmetic miss: `ForestTest.boundary` runs this every Heartbeat for every participant, so on a
-- `ride` drive a hunter standing on HIS stand (x 3350, z -2600) was measured against the ROAD's
-- stand 3 (x 2730, z -2070) -- 815 studs, far outside the 12-stud circle -- and `root.CFrame` was
-- rewritten onto the road's circle every tick. He could not stand on his own stand at all.
--
-- `layout` IS OPTIONAL so a spec can ask any layout's circle without a drive; omitted, it is the one
-- this drive is actually standing on, which is the only answer production may have.
function ForestTest.withinStand(position: Vector3, standIndex: number, layout: any?): boolean
	local home = Data.standPosition(standIndex, layout or chosen.layout)
	local flat = Vector3.new(position.X - home.X, 0, position.Z - home.Z)
	return flat.Magnitude <= Data.PICK.standRadiusStuds
end

-- WHERE THE WALL IS FOR THIS POSITION: nil inside the circle, and ON the circle outside it -- at the
-- SAME BEARING from the stand, keeping the position's own height (task 166).
--
-- THE POINT OF THE SIGNATURE IS WHAT IT CANNOT RETURN. Karen: *"we need boundries but not put back
-- where it started"*. The only value this function ever gives back is a point at EXACTLY
-- `standRadiusStuds` from the stand on the ray the player walked out along, so "put back to the
-- middle" is not expressible -- and `forest_stand.spec` asserts that for a ring of bearings and for
-- a player 200 studs away, which is the one claim a clamp has to keep.
--
-- PURE, so the whole rule is drivable with hand-written numbers: no character, no physics, no drive.
function ForestTest.boundaryPoint(position: Vector3, standIndex: number, layout: any?): Vector3?
	-- THE SAME LAYOUT FOR BOTH READS. Asking `withinStand` about one circle and then clamping onto
	-- another is two answers to "where is his stand", which is how round 1 put a hunter on the road.
	local where = layout or chosen.layout
	if ForestTest.withinStand(position, standIndex, where) then
		return nil
	end
	local home = Data.standPosition(standIndex, where)
	local flat = Vector3.new(position.X - home.X, 0, position.Z - home.Z)
	-- `withinStand` was false, so the flat distance is strictly greater than the radius and the
	-- radius is positive: `Unit` cannot be asked of a zero vector here.
	local on = home + flat.Unit * Data.PICK.standRadiusStuds
	return Vector3.new(on.X, position.Y, on.Z)
end

-- THE NEAREST STAND to a position, which is how a hunter picks one: he walks to it. Karen asked for
-- a square to select and save; standing on it IS the selection, and the save is the timer running
-- out or the player confirming -- neither of which this function needs to know about.
function ForestTest.nearestStand(position: Vector3, layout: any?): number
	local where = layout or chosen.layout
	local best, bestDistance = 1, math.huge
	for index = 1, where.standCount do
		local stand = Data.standPosition(index, where)
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
	-- THE DRIVE'S RED DEER (task 239), and all three are ABOUT ONE DRIVE, so `newDrive` resets them.
	-- `waveIndex` above counts the SESSION's waves and is what the console lines are numbered by;
	-- `driveWave` counts this drive's, which is what the ordinal is drawn against. `deerWave` is nil
	-- until the drive's first wave draws it -- lazily, because `newDrive` is also called by a spec
	-- and by `start` before `state.rng` means anything.
	driveWave = 0,
	deerWave = nil :: number?,
	deerDone = false,
	active = {} :: { { centre: Vector3, handles: { any }, at: number, turnsBack: boolean, id: string } },
	picks = {} :: { [number]: { index: number, lockedAt: number? } },
	-- WHICH ROLE A PLAYER HAS ASKED FOR AND NOT YET BEEN GIVEN, in Karen's own words (task 151,
	-- beater-kit design section 9; task 157 made it a one-shot). It sits beside `picks` because it is
	-- the same kind of fact -- what this player chose in this playtest -- and it is A REQUEST AND NOT
	-- THE TRUTH: `Player.Team`, written by `Match.Body.setTeam` from the drive's own roster, is the
	-- truth, and `ForestTest.roleFor` reads it. It is CLEARED when it is honoured, so it can never
	-- defeat the drive's rotation. This module writes no Instance for it and does not require
	-- `Match`.
	requests = {} :: { [number]: string },
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
		-- TASK 153: how many animals a real beater has walked up to and flushed out of a file.
		flushed = state.flushed or 0,
		-- TASK 172: ...and how many first STOOD AND LOOKED at him before they went, plus how many of
		-- the stocked wood are still on their feet -- the two numbers the staged encounter is proved
		-- with, and the second is why the wood is never re-stocked.
		noticed = state.noticed or 0,
		-- TASK 239: which wave of THIS drive carries the red deer, how far through the drive the
		-- metronome is, and whether the group has gone. Three numbers rather than a boolean,
		-- because "no deer yet" and "no deer due yet" are different answers and a probe watching a
		-- drive has to be able to tell them apart.
		driveWave = state.driveWave or 0,
		deerWave = state.deerWave,
		deerDone = state.deerDone == true,
		restStocked = state.restStocked == true,
		restAlive = ForestTest.restAlive(),
		active = #state.active,
		boars = if state.runtime then state.runtime:count() else 0,
		-- TASK 179, rotation since TASK 193: which of the drive places this drive is standing on,
		-- where the choice came from ("default" | "rotation" | "override") and WHAT COMES NEXT. The
		-- SOURCE is the only thing that stops a forced playtest being reported as the rotation,
		-- because `DHForestLayout` is not a `DHFlag_*` name and the harness does not refuse a run
		-- while it is set (design 11, D3).
		--
		-- `layoutNext` REPLACES task 179's `layoutBag`, and it answers the same question a reader of
		-- that field was actually asking -- which place comes after this one. With a cycle there is
		-- no bag to report, and a rotation's next is knowable, which a shuffled bag's was not.
		layout = chosen.name,
		layoutSource = chosen.source,
		-- THE NEXT **ROTATED** PLACE, which during a forced drive is not the one after `layout`
		-- (round 2, note 3). It reads the cycle, like the deal does.
		layoutNext = Data.nextLayout(chosen.cycle),
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
--
-- ...AND A REAL BEATER IS (task 153). Karen: *"beater are behind animals and moving towards hunter
-- line (road) like in real life ... we will try walk spook, use horn have that feeling"*. Every
-- player in this world used to be a `shooter` whatever role they had asked for, so her walk SPOOKED
-- the animals (`PACE.SPOOK_STUDS`, 30 studs, "a man who is not driving") instead of PUSHING them --
-- which is the one thing a beater does. With `kind = "driver"` the Brain's existing branch takes
-- over: a driver inside a flush radius moves the animal off at a walk or a trot, and only a REAL one
-- inside `PACE.DRIVER_RUN_STUDS` (25) makes it run (`Boar.CONFIG.PACE`). Nothing new is invented
-- here; the door was already open and this world was handing it the wrong word.
-- EVERY REAL BEATER IN THIS WORLD: the players who asked to be one and have a body (task 153).
-- One list, read by the two things that need it -- what a boar can perceive (`boarThreats`) and
-- which animals a beater is close enough to flush (`stepLines`) -- so "who is pushing" is answered
-- in one place and cannot be answered twice differently.
-- THE BOTS' THREATS, AS ONE INJECTED SOURCE (task 161). Set once at the composition root to
-- `Bots.threats`; nil until then, and nil is "there are no bots", which is this file before task 161
-- by every branch.
--
-- INJECTED RATHER THAN REQUIRED, because no owner requires another owner -- the rule this world's
-- boot and `MatchBoot` are both written to. It is the same shape `Boar.setModelSource`,
-- `Body.setAccessorySource` and `Markers.setReaders` already have in this repo.
local botThreatSource: (() -> { { id: string, position: Vector3, kind: string } })? = nil

function ForestTest.setBotThreats(fn: (() -> { { id: string, position: Vector3, kind: string } })?)
	botThreatSource = fn
end

-- What that source answers NOW, or an empty list. Never cached: a rig that has just been built or
-- just destroyed must change this answer on the next heartbeat, which is what makes the phantom
-- suppression in `boarThreats` level-triggered rather than a boolean somebody remembered to pass.
function ForestTest.botThreats(): { { id: string, position: Vector3, kind: string } }
	local source = botThreatSource
	if source == nil then
		return {}
	end
	local ok, out = pcall(source)
	if not ok or type(out) ~= "table" then
		return {}
	end
	return out
end

-- EVERY BEATER IN THIS WORLD WITH A BODY -- and "real" has always meant *as against a phantom*, which
-- is exactly what a bot is not: somebody IS standing there. So since task 161 this list has two
-- sources, the players who asked to be beaters and the bot beaters, and it is still ONE list -- read
-- by the two things that need it (`boarThreats` and `stepLines`'s flush, through
-- `spookNearBeaters`), so "who is pushing" is answered in one place and cannot be answered twice
-- differently. A bot's walk therefore flushes a file through the SAME door a player's walk does,
-- with no second push mechanism and no new rule.
function ForestTest.realBeaters(): { { id: string, position: Vector3 } }
	local out = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character.PrimaryPart
		if root ~= nil and ForestTest.roleOfPlayer(player) == "beater" then
			table.insert(out, { id = tostring(player.UserId), position = (root :: BasePart).Position })
		end
	end
	for _, threat in ipairs(ForestTest.botThreats()) do
		if threat.kind == "driver" then
			table.insert(out, { id = threat.id, position = threat.position })
		end
	end
	return out
end

-- PURE. The nearest of them to a point, flat, and how far away it is -- `nil, math.huge` for none.
function ForestTest.nearestBeater(point: Vector3, beaters): (Vector3?, number)
	local best, gap = nil, math.huge
	for _, beater in ipairs(beaters) do
		local away = Vector3.new(beater.position.X - point.X, 0, beater.position.Z - point.Z)
		if away.Magnitude < gap then
			best, gap = beater.position, away.Magnitude
		end
	end
	return best, gap
end

-- THE LINE THE CONSOLE GETS WHEN A BEATER FLUSHES SOMETHING, taken once (task 153). The module
-- never prints -- the boot prints what `step` returns -- and this keeps it that way.
function ForestTest.takeFlushLine(): string?
	local line = state.flushLine
	state.flushLine = nil
	return line
end

-- WHICH WAVES GET A PHANTOM BEATER THIS TICK, and it is the whole of the "one push source" rule
-- (task 161). PURE: a wave list in, a wave list out, so `forest_stand.spec` drives BOTH states with
-- hand-written tables -- which is what round 1 found the old shape could not do, because nothing in
-- the spec place ever fills `state.active` and the assertion "no phantom" was true with the rule
-- deleted.
--
-- THE RULE: while any bot beater is pushing, NO wave gets a phantom. A body Karen can SEE pushes; an
-- invented position 11 studs behind the herd must not push at the same time, or the animals are
-- moved by something nobody is standing on and the thing she is watching is not the cause.
--
-- OFF A LIVE FACT RATHER THAN A BOOLEAN PASSED IN, and decided by the owner of the phantoms rather
-- than by the composition root: a drive whose flag is on but whose first rig is not built yet still
-- gets its phantoms, so the push never gaps. With no bots this returns the list it was given, which
-- is this file before task 161.
--
-- IT CANNOT STALL THE DRIVE, and that is worth saying because it is the obvious fear: a released
-- line does not MOVE because of the phantom. `Boar.CONFIG.LINE` is the mode in which an animal stops
-- deciding and walks to the point it was given (`releaseLine` computes the route and the crossing),
-- and this world turns that mode on at its own boot. The phantom's job was to make a herd RUN rather
-- than graze -- which is now a bot's job, through the same `PACE` and flush doors and from a body
-- that is really there (`realBeaters`).
function ForestTest.wavesToPush(waves, bots)
	for _, threat in ipairs(bots or {}) do
		if threat.kind == "driver" then
			return {}
		end
	end
	return waves or {}
end

function ForestTest.boarThreats(now: number)
	local out = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character.PrimaryPart
		if root then
			table.insert(out, {
				id = tostring(player.UserId),
				position = root.Position,
				kind = ForestTest.threatKind(ForestTest.roleOfPlayer(player)),
			})
		end
	end
	-- THE BOTS, AS THEY ARE (task 161): real bodies, each carrying its own kind and NO `phantom`
	-- mark, because somebody IS standing there.
	local bots = ForestTest.botThreats()
	for _, threat in ipairs(bots) do
		table.insert(out, threat)
	end
	-- ...AND THE PHANTOMS STAND DOWN WHILE A BOT BEATER IS PUSHING. The RULE is
	-- `ForestTest.wavesToPush`, pure and just above, so a spec drives both states with a hand-written
	-- wave list; this is the one call of it.
	for _, wave in ipairs(ForestTest.wavesToPush(state.active, bots)) do
		local centre = ForestTest.herdShape(wave.handles)
		if centre ~= nil then
			local dz = (centre :: Vector3).Z - Data.roadZ((centre :: Vector3).X, chosen.layout)
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
--
-- SINCE TASK 157 IT HAS NO PRODUCTION CALLER, and that is said here rather than left to be
-- discovered: the report's window is now the real drive's own phases (`Match.PhaseChanged`, in both
-- worlds, docs/design/forest-drive.md section 7.1). This and `driveIndexAt` are RETAINED as the pure
-- window arithmetic `forest_stand.spec` drives, and `Data.DRIVE.seconds` is still the one home of the
-- number the forest's `DRIVE_SECONDS` override is read from. If nothing claims them by the next
-- audit they are archived with a note (rule 7) -- a function nothing reads is the next reader's trap.
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
		-- THE LIVE LAYOUT HAS TO HAVE THE STAND (task 179), the same guard `pickOf` makes: a pick of
		-- 7 left over from a nine-stand road would aim every wave of a five-stand ride at a point
		-- past the end of the line.
		if pick.lockedAt ~= nil and pick.index <= chosen.layout.standCount then
			return Data.standX(pick.index, chosen.layout)
		end
	end
	-- CLAMPED INTO THE LIVE LAYOUT (task 179): `defaultIndex` is 5 and every shipped layout has
	-- at least five stands, so this changes no answer today -- it is here so adding a shorter
	-- layout cannot aim every wave past the end of its line.
	return Data.standX(math.min(Data.PICK.defaultIndex, chosen.layout.standCount), chosen.layout)
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
	local wanted = if composition then Boar.compositionSize(composition, Boar.CONFIG) else (spec.size or 1)
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
	local centre = Data.wavePoint(standX, spec, chosen.layout)
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
		local dz = if centre then centre.Z - Data.roadZ(centre.X, chosen.layout) else nil
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

-- A PICK IS A STAND INDEX AND A LAYOUT MAY NOT HAVE IT (task 179). The ride has 5 stands and the
-- road has 9, so stand 7 exists in one and not the other -- and `Data.standX(7)` on the ride answers
-- a point 260 studs past the end of the line that is NOT a stand, which `standArea`, `boundary` and
-- `hunterStandX` would all believe.
--
-- IT IS BELT OVER THE BRACE, and that is deliberate rather than defensive. The drive boundary
-- already drops every pick (`ForestTestBoot`'s `Assigning` handler calls `clearPick` for every
-- player and `Markers.clearRings()`), and `Match.Body.place` already puts him on a post the new
-- layout actually has. This guard is what happens if either of those ever stops being true: the
-- answer becomes "no pick", which is a state this game already has and tests -- *no rule during the
-- pick window* -- rather than a hunter held to a point in a wood.
function ForestTest.pickOf(userId: number)
	local pick = state.picks[userId]
	if pick == nil or pick.index > chosen.layout.standCount then
		return nil
	end
	return pick
end

-- Opens the 10-second window. Nothing is locked yet: where he walks IS the choice.
--
-- `standIndex` IS WHICH STAND THE OPEN PICK POINTS AT (task 175), and it is optional so every caller
-- written before it keeps the default stand it always got. KAREN, 2026-10-13 ~19:05: *"for shooter -
-- get in your stand (we need to show where is his stand this circle has to remain all a time"*. The
-- ring task 166 draws is drawn round `standIndexOf` below, so an open pick has to point at the stand
-- the drive actually PLACED him on rather than at stand 5 -- which is the right answer for a solo
-- hunter (`standIndexFor(1)` is 5) and the wrong one for everybody else in a full drive.
--
-- IT IS STILL AN OPEN PICK AND CHANGES NO RULE. `standArea`, `boundary` and `hunterStandX` all test
-- `lockedAt` and ignore an open pick on purpose -- "no rule during the pick window" -- so what this
-- argument moves is the thing that is DRAWN and nothing that is enforced.
function ForestTest.openPick(userId: number, now: number, standIndex: number?)
	local index = math.min(standIndex or Data.PICK.defaultIndex, chosen.layout.standCount)
	state.picks[userId] = { index = index, lockedAt = nil, openedAt = now } :: any
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

-- WHICH STAND IS THIS HUNTER'S, SHOWN OR ENFORCED -- the locked pick, or the open one he was placed
-- on, or nil when he has no pick at all (task 175). PURE given the state; no role, no `Player`.
--
-- IT IS THE ONE QUESTION THE RING ASKS, and that is the whole reason it exists rather than the
-- caller reading `pickOf(...).index` itself. "Where is his circle drawn" and "where may he shoot"
-- are DIFFERENT questions with different answers during the pick window -- this one answers for a
-- hunter still choosing and `standArea` deliberately does not -- so a reader that wanted the first
-- and reached for the second would start enforcing a boundary that is not yet his.
function ForestTest.standIndexOf(userId: number): number?
	local pick = ForestTest.pickOf(userId)
	if pick == nil then
		return nil
	end
	return pick.index
end

-- THIS HUNTER'S STAND AS AN AREA, for the weapon's fire gate (task 171): the circle he LOCKED, or
-- nil when he has not locked one. The same `Data.standPosition` and the same
-- `Data.PICK.standRadiusStuds` the wall below is built from, so "where he may shoot" and "where he
-- may walk" cannot drift apart -- they are one circle, asked two ways.
--
-- NIL IS "NO RULE" AND THAT IS THE HONEST ANSWER DURING THE PICK WINDOW: for the 15 s in which
-- walking to a stand IS the choice, there is no circle to be outside of (`Weapon.Rules.outsideStand`
-- says why the default is permissive). The role is NOT asked here: `Match.standAreaFor` has already
-- refused anybody who is not a hunter, which is the same split as `ForestTest.boundary`'s `role`
-- parameter -- the caller holds the `Player`, this module keys by `userId`.
-- MAY THIS PLAYER USE A HIGH SEAT? (task 221 round 3.) INJECTED, exactly as
-- `Weapon.setEntitlementProvider` and `Body.setLookProvider` are, so this world module learns
-- nothing about a shop, an item id or a price -- it asks one boolean of whatever the composition
-- root wired. nil provider is nil answer, which is "nothing said", which is no rule.
local seatProvider: ((number) -> boolean?)? = nil

function ForestTest.setSeatProvider(provider: ((number) -> boolean?)?)
	seatProvider = provider
end

local function seatPaidFor(userId: number): boolean?
	local ask = seatProvider
	if ask == nil then
		return nil
	end
	-- THROUGH `pcall`, the discipline every injected provider in this repo is asked through: a
	-- provider that throws must leave the game as it was and not refuse every shot in the drive.
	local ok, answer = pcall(ask, userId)
	if not ok or type(answer) ~= "boolean" then
		return nil
	end
	return answer
end

function ForestTest.standArea(userId: number)
	local pick = ForestTest.pickOf(userId)
	if pick == nil or (pick :: any).lockedAt == nil then
		return nil
	end
	local deck = Seats.deckTopY(pick.index)
	return {
		centre = Data.standPosition(pick.index, chosen.layout),
		radius = Data.PICK.standRadiusStuds,
		-- WHERE HIS PLATFORM'S FLOOR IS, or nil for "no height rule" -- which is every ground stand
		-- and every other world (task 218, design section 5.2). Read off the SEAT THE WORLD BUILT,
		-- so "where may he shoot" and "what is he standing on" are one fact asked once: a stand
		-- whose seat was refused answers nil here and is a ground stand in every respect.
		minY = deck,
		-- ...AND WHETHER THIS MAN MAY USE IT (task 221 round 3). Only asked where there IS a seat:
		-- a ground stand has nothing to pay for, and answering `false` there would be a rule about
		-- a platform that does not exist.
		seatPaid = if deck ~= nil then seatPaidFor(userId) else nil,
	}
end

-- ---------------------------------------------------------------- which role, in this world only
--
-- THE FOREST TEST HAS NO BEATERS OF ITS OWN: its drive's beaters are phantom positions with nobody
-- standing on them (`ForestTest.boarThreats`), and Karen tests alone. So that she can BE one she
-- asks for it -- by typing in the chat, or through the Director's start switch.
--
-- SINCE TASK 157 THAT ASK IS A REQUEST AND NOT THE TRUTH, and the change is not cosmetic. The real
-- `Match` runs in this place now, and it reads `state.assignment` -- not `Player.Team`. So the old
-- `setRole` + `Body.setTeam` pair did not merely make two deciders of one fact: it did not WORK. A
-- player dressed as a beater was still a SHOOTER to the drive -- armed, push-credited and
-- unprotected by the safety rule.
--
-- SO: the request is recorded here, `Match.requestTeam` is what honours it, `Match.Body.setTeam`
-- stays the one writer of `Player.Team`, and every reader below asks THE TEAM. `roleFor` is the one
-- translation from a team to Karen's word, and `Match.Body.teamForWord` remains the one translation
-- the other way (this file still does not require `Match`).
--
-- `roleOf`, `setRole`, `clearRole` and `state.roles` are gone, archived with a note at
-- `backups/2026-10-11_task157_forest_roles_and_placement.txt` (rule 7).
-- Design: docs/design/forest-drive.md section 5.2

export type RoleWord = "hunter" | "beater"

-- He spawns as a hunter, which is what this world has always put him down as.
ForestTest.ROLE_DEFAULT = "hunter" :: RoleWord

-- PURE. The role in a line of chat, or nil for anything else -- including an empty line and a word
-- with no slash. Case- and whitespace-insensitive, because Karen types it while playing.
function ForestTest.parseRole(text: string?): RoleWord?
	if text == nil then
		return nil
	end
	local word = string.lower((string.gsub(text, "%s", "")))
	if word == "/beater" then
		return "beater"
	elseif word == "/hunter" then
		return "hunter"
	end
	return nil
end

-- WHICH ROLE A TEAM IS, IN KAREN'S WORDS. PURE, and the one translation from the fact the engine
-- replicates (`Player.Team`, written only by `Match.Body.setTeam`) to the word this world speaks.
-- `Data.PUSH_TEAM` already exists so that nothing hard-codes a team name here.
function ForestTest.roleFor(team: string?): RoleWord
	return if team == Data.PUSH_TEAM then "beater" else ForestTest.ROLE_DEFAULT
end

-- A player's role, read off the live `Player.Team`. Not a second answer: the drive writes that field
-- and this reads it, exactly as the client's own `Match.myTeam()` does (`docs/design/drive.md`
-- section 9.3: *"From Player.Team, NOT from the snapshot"*).
function ForestTest.roleOfPlayer(player: Player): RoleWord
	local team = player.Team
	return ForestTest.roleFor(if team then team.Name else nil)
end

-- ONE PENDING REQUEST PER PLAYER, and it is consumed when it is honoured.
--
-- ONE-SHOT ON PURPOSE (design section 5.3): a request that stuck would defeat the rotation Karen
-- asked for -- *"you start as a hunter then next round you are beater"* -- which is
-- `SWAP_TEAMS_EACH_DRIVE`'s job and not this table's. The start switch therefore only decides the
-- parity of the first drive.
function ForestTest.requestRole(userId: number, role: RoleWord): RoleWord
	state.requests[userId] = role
	return role
end

-- Returns the request AND clears it, so a caller cannot honour the same ask twice.
function ForestTest.takeRequest(userId: number): RoleWord?
	local role = state.requests[userId]
	state.requests[userId] = nil
	return (role :: any) :: RoleWord?
end

function ForestTest.pendingRequest(userId: number): RoleWord?
	return (state.requests[userId] :: any) :: RoleWord?
end

function ForestTest.clearRequest(userId: number)
	state.requests[userId] = nil
end

-- WHO IN THIS WORLD IS NOT WIRED UP YET (task 202), as a reconciliation step rather than an event.
--
-- KAREN'S `/beater` AND THE DIRECTOR'S `DHForestStartRole` BOTH STOPPED WORKING, and neither of them
-- is where the fault was. MEASURED in the Forest Test on 2026-10-17, twice running: a Play Solo
-- session printed neither `[ForestTest] <name> asked to join as a <role> (start switch)` nor
-- `[ForestTest] <name> is a <role> at (...)`, and BOTH of those prints are inside
-- `ForestTestBoot`'s `Players.PlayerAdded` handler -- which also holds the `player.Chatted`
-- connection her `/beater` travels down. The event had already fired. Play Solo puts the local
-- player into `Players` while the server scripts are still running, and that root now YIELDS for
-- seconds before it reaches the connection (`places: 3 dressed, 3028 planted ... 2.73s`, plus the
-- asset loads), so by the time anybody was listening there was nothing left to hear.
--
-- A SECOND EDGE HANDLER WOULD BE THE SAME BUG AGAIN. "Wire him when he joins" is a statement about
-- an INSTANT, and this repo has now lost that instant twice -- the gun that reached the client after
-- the camera's first render step (`Camera.Rig`'s own header) and this. "Everybody in this world is
-- wired" is a statement about a STATE, so the boot asks this every tick and acts on the answer: a
-- player who joined before anything was listening, during a yield, or in the same frame as the
-- Heartbeat is wired on the next one. It is the `Weapon.refreshArming` / `Horn.refreshCarry`
-- discipline, for the reason those two carry: *"every edge-triggered grant in this repo has been
-- measured missing one"*.
--
-- PURE, AND IT WRITES NOTHING -- not even `wired`, which the caller owns, because the caller is what
-- knows whether the wiring actually succeeded. nil rather than an empty table when there is nothing
-- to do, so the settled case costs one loop and no allocation.
function ForestTest.toWire(players: { Player }, wired: { [number]: boolean }): { Player }?
	local out = nil
	for _, player in ipairs(players) do
		if not wired[player.UserId] then
			out = out or {}
			table.insert(out, player)
		end
	end
	return out
end

-- WHOSE ROLE REQUEST IS OWED AND MAY BE OFFERED TO THE DRIVE ON THIS TICK (task 214), as a
-- reconciliation step rather than an event. `toWire`'s shape above, for `toWire`'s reason, and it is
-- the same defect one layer further in: task 202 fixed "nobody was listening when he joined", and
-- this fixes "nobody asked again after he joined".
--
-- MEASURED IN THE FOREST TEST, 2026-10-19, on Karen's own path (lodge -> truck pad -> drive), with
-- `DHForestStartRole=beater`: the request was recorded at the join (`asked to join as a beater
-- (start switch)`), and she then spent THE WHOLE INTERMISSION as a hunter -- `team=Shooters
-- hand=[Shotgun]`, placed on stand 5 at the road, a ring drawn round it and the objective reading
-- *get to your stand* -- and was flipped only at GO (`is now a beater (team=Drivers)`), which
-- respawned her 580 studs north in the middle of the fanfare. THE REQUEST WAS NEVER LOST: it was
-- offered to the drive at exactly ONE INSTANT, the `Running` edge, and the lobby moved the moment
-- she enrols to AFTER the one instant that could have used it. Before the lobby (177/209) she was
-- in the drive from the frame she joined, so `Assigning` and the `Running` edge were the same
-- intermission and the gap could not be seen.
--
-- `settled` IS WHY THIS IS NOT SIMPLY CALLED EVERY TICK, and it is a measurement of `Body.place`
-- rather than a precaution: that function connects `CharacterAdded` and then calls
-- `LoadCharacter`, and it disconnects only once its own pivot has finished -- so two placements in
-- flight for one player both pivot the SAME new character, one to the stand and one to the beater
-- line, and which one lands last is a coin flip. MEASURED, 2026-10-19, with the first version of
-- this sweep, which guarded on the character alone: `[place] spawn ... at (3030, 237.6, -1517)`
-- (the beater line) and then `[place] spawn ... at (3030, 143.5, -2097)` (the road) for one
-- enrolment, and she finished the intermission a beater -- with the horn, on the HUNTERS' stand.
--
-- SO THE RECORD IS "WHAT HE WAS WHEN HIS BODY LAST STOOD STILL", AND IT IS TWO FACTS, because the
-- race has two halves and the character alone only covers one of them:
--   * `character` -- the Model the caller watched land. A respawn replaces it, so a stale entry
--     answers false by construction, which covers the window AFTER `LoadCharacter` has swapped him.
--   * `team` -- the `Player.Team` he had at that moment. `assignTeams` is applied BEFORE
--     `placePlayers` in the same dispatch, so a drive that is about to move a man has already
--     written his new side -- which is the only signal available during the window BEFORE
--     `LoadCharacter` swaps anything, and it is exactly the window the measurement above fell into.
-- Together they say: his body has stood still since the drive last changed its mind about him.
--
-- PURE OF THE CALLER'S RECORD and it writes nothing -- not `settled`, which the caller owns, and not
-- `state.requests`, which `takeRequest` consumes when the drive has actually honoured the ask. nil
-- rather than an empty table when there is nothing to do, so the settled case costs one loop and no
-- allocation.
export type Settled = { character: Instance, team: Instance? }

function ForestTest.toHonour(players: { Player }, settled: { [number]: Settled }): { Player }?
	local out = nil
	for _, player in ipairs(players) do
		local seen = settled[player.UserId]
		local character = player.Character
		if
			state.requests[player.UserId] ~= nil
			and character ~= nil
			and seen ~= nil
			and seen.character == character
			and seen.team == player.Team
		then
			out = out or {}
			table.insert(out, player)
		end
	end
	return out
end

-- WHAT A BOAR SEES WHEN IT LOOKS AT THIS PLAYER (task 153). PURE, and one line, because the whole
-- point is that "which role has she asked for" and "what kind of stimulus is she" are the same fact
-- in two vocabularies: a beater is a `driver` and anybody else is a `shooter`. The Brain's own
-- comment names this string; `Match.Body.boarStimuli` is the DEV world's half of the same mapping,
-- from a team instead of from a word.
function ForestTest.threatKind(role: RoleWord?): string
	return if role == "beater" then "driver" else "shooter"
end

-- WHICH ROLE A PLAYER STARTS AS, from the switch the Director sets (task 153). PURE: whatever the
-- `ServerStorage` attribute holds, in; a role or nil for "nobody has said". Karen types
-- `/beater` with a slash and the attribute is set without one, so both are read -- the point of the
-- switch is that she never has to type anything.
function ForestTest.startRole(value: any): RoleWord?
	if typeof(value) ~= "string" then
		return nil
	end
	local word = string.lower((string.gsub(value :: string, "%s", "")))
	if string.sub(word, 1, 1) ~= "/" then
		word = "/" .. word
	end
	return ForestTest.parseRole(word)
end

-- HOW LONG THIS WORLD'S DRIVE RUNS, from the switch the Director sets (task 201 part 2). PURE:
-- whatever the `ServerStorage` attribute holds, in; a number of seconds, or nil for "nobody has
-- said" and then the world's own `DRIVE.seconds`.
--
-- IT REFUSES RATHER THAN CLAMPS SILENTLY. A value under `DRIVE_SECONDS_MIN` would end the drive
-- before its own first release, and a value above the world's own length would be making a
-- playtest LONGER -- which nobody asked for and which one mistyped digit could do. Out of range is
-- nil, which is "nobody has said", which is the default: a switch that cannot be set to something
-- harmful is a switch nobody has to remember the bounds of.
function ForestTest.driveSeconds(value: any, default: number?): number?
	local full = default or Data.DRIVE.seconds
	local seconds = if typeof(value) == "number" then value else tonumber(tostring(value or ""))
	if seconds == nil then
		return nil
	end
	seconds = math.floor(seconds)
	if seconds < Data.DRIVE_SECONDS_MIN or seconds > full then
		return nil
	end
	return seconds
end

-- HOW FAR THE CLAMP HAS TO MOVE A BODY BEFORE THE WALL ASKS WHERE THE GROUND IS. Two studs: a
-- hunter pushing against his circle is clamped by a fraction of a stud a frame, and the mid-drive
-- respawn the lift exists for arrives from the road spawn 900 studs away.
local LIFT_WHEN_MOVED_STUDS = 2

-- HOW MANY TIMES THE WALL HAS HAD TO LIFT A BODY OUT OF THE HILL (task 192). It is one per respawn
-- during a drive and zero otherwise, which is a number to read rather than a thing to assume: see
-- `ForestTest.boundary` below for what it counts.
local boundaryLifts = 0

function ForestTest.boundaryLifts(): number
	return boundaryLifts
end

-- HOLDS A LOCKED HUNTER INSIDE HIS STAND'S CIRCLE. Returns the position it stopped him at, or nil.
--
-- IT IS A WALL, NOT A LEASH, AND TASK 166 IS THAT CHANGE. Karen, 2026-10-12: *"it always put me at
-- the same place even I moved a bit we need boundries but not put back where it started"*. The
-- circle is four times bigger (`Data.PICK.standRadiusStuds`, measured and reasoned about there) and
-- the two writes below are what make the edge read as a wall instead of as a tug:
--
--   1. THE POSITION IS CLAMPED ONTO THE CIRCLE and never anywhere else -- `ForestTest.boundaryPoint`
--      is pure and is the only thing that decides where, so this function cannot teleport anybody to
--      the middle of his stand.
--   2. THE OUTWARD VELOCITY IS REMOVED. This is the new half. Clamping alone leaves a player who is
--      holding W pushing into the wall at full speed, so he is written back every single frame and
--      what he feels is a rubber band; taking the outward part of the assembly's velocity away once
--      he reaches the edge makes him STOP there. Only the component pointing away from the stand
--      goes: sideways motion along the circle and the whole of the vertical stay, so he can still
--      walk around the edge and still falls normally.
--
-- IT STILL DOES NOT FREEZE HIM. *"I want tomorrow to test shooting and walking"* -- anchoring the
-- character would break the thing she is testing, so walking out simply stops being possible.
-- `lift` IS THE ONE PLACEMENT RULE, HANDED IN (task 192), and it is here because this wall was the
-- second half of Karen's sentence: *"when I respawn I die"*.
--
-- MEASURED, twice, in the live place. A hunter who presses Reset in the middle of a drive is
-- respawned by the engine at `Workspace.ForestRoadSpawn` -- (3000, 138.5, -2109), 900 studs away --
-- and this wall then clamps his X and Z onto his own stand's circle on the very next Heartbeat
-- WHILE KEEPING `position.Y`, because that is what `boundaryPoint` returns. He arrives at
-- (3549, 143.7, -2990): 11.7 studs from stand 4, which is the clamp, and **47.8 studs under the
-- terrain**, which is the hill it put him inside. Both proof runs produced that point to the stud.
--
-- SO THE WALL IS HORIZONTAL AND IT SAYS SO. `lift` is `Match.Body.liftOntoGround`, the one owner's
-- own rule, and it is ONE-SIDED: it moves a point that is more than `Body.maxBelowGround()` studs
-- INSIDE the ground, and never touches one that is on it or above it -- so a hunter jumping at the
-- edge of his circle is clamped exactly as he was and is not pinned to the floor.
--
-- `nil` IS THE OLD BEHAVIOUR, for a spec that drives this with no Workspace at all.
function ForestTest.boundary(
	userId: number,
	root: BasePart,
	role: RoleWord?,
	lift: ((Vector3, number?) -> (Vector3, boolean))?
): Vector3?
	-- A BEATER IS NOT HELD TO A STAND (task 153), and without this line the whole task is dead on
	-- arrival: a beater walks 580 studs south through the wood (240 when task 153 wrote this line),
	-- and a circle round the stand
	-- she locked as a hunter would drag her back to the road every heartbeat. The boundary is the
	-- HUNTER's rule -- Karen: *"hunter has square where can select stand within 10s and save then he
	-- can move few steps"*.
	--
	-- THE ROLE IS A PARAMETER SINCE TASK 157, because the truth of it is now `Player.Team` and the
	-- caller is the one holding the `Player` -- this module keys by `userId` and never holds one
	-- (the discipline `picks` and `requests` both follow). `nil` means "nobody said", which is the
	-- hunter this world starts her as.
	if (role or ForestTest.ROLE_DEFAULT) ~= "hunter" then
		return nil
	end
	local pick = ForestTest.pickOf(userId)
	if pick == nil or (pick :: any).lockedAt == nil then
		return nil
	end
	local to = ForestTest.boundaryPoint(root.Position, pick.index)
	if to == nil then
		return nil
	end
	local at = to :: Vector3
	-- THE LIFT IS ASKED ONLY OF A BODY THAT WAS TELEPORTED HERE, NOT OF ONE WALKING INTO THE WALL
	-- (Reviewer round 1, note 3: `lift` costs a raycast, and a hunter leaning on his circle's edge
	-- is the frame-by-frame case task 166 was written around). The discriminator is the clamp's own
	-- DISPLACEMENT: a man walking into the wall is moved a fraction of a stud a frame, while the
	-- respawn this exists for arrives 900 studs away at the road spawn. `LIFT_WHEN_MOVED_STUDS` is
	-- the line between them, so the common case costs nothing and the rare one is still caught.
	if lift ~= nil and (at - root.Position).Magnitude > LIFT_WHEN_MOVED_STUDS then
		local lifted, moved = lift(at)
		if moved then
			at = lifted
			boundaryLifts += 1
		end
	end
	root.CFrame = CFrame.new(at) * (root.CFrame - root.CFrame.Position)
	-- THE OUTWARD PART OF THE VELOCITY, GONE. `AssemblyLinearVelocity` is the whole character's, not
	-- one part's, which is what a walking Humanoid has (the engine welds the rig into one assembly).
	--   https://create.roblox.com/docs/reference/engine/classes/BasePart#AssemblyLinearVelocity
	-- `outward` is flat, so this subtraction never touches the fall.
	local home = Data.standPosition(pick.index, chosen.layout)
	local outward = Vector3.new(at.X - home.X, 0, at.Z - home.Z)
	if outward.Magnitude > 0 then
		local away = outward.Unit
		local velocity = root.AssemblyLinearVelocity
		local radial = velocity:Dot(away)
		if radial > 0 then
			root.AssemblyLinearVelocity = velocity - away * radial
		end
	end
	return at
end

-- ---------------------------------------------------------------- the wood a beater walks into
--
-- TASK 154. KAREN, 2026-10-11, after the first beater playtest:
--   *"didn;t see any animals probably need to wait 10s ?"*
--   *"so animals already there somewhere in bushes close to trees ect"*
--   *"once I get a bit closer they just run away without stop it's not like they cool down they
--    spooked and run away / so from me direction they looking they run away"*
--   *"horn reach is further once they hear also run without stop"*
--
-- Three facts and three answers, and the data for all three is in `Data.REST` and `Data.SPOOK`.
-- Nothing here writes a boar's position, its state or its path: the wood is stocked through
-- `Runtime:spawnSounder` and emptied through `Runtime:spook`, which are the two doors the wave path
-- has always used.

-- IS ANYBODY IN THIS WORLD A BEATER? Read off the TEAM and not off a body, because the wood has to
-- be full before she has finished falling onto the ground.
--
-- THE TIMING PROPERTY SURVIVES TASK 157's CHANGE, and that is why it is safe to read the team here:
-- `enterAssigning` emits `assignTeams` BEFORE `placePlayers`, so `Player.Team` is written one effect
-- before the respawn that makes the character -- the same guarantee the old role table gave, now
-- from the effect order (docs/design/forest-drive.md section 5.2).
--
-- `teams` IS THE TEST SEAM AND IT IS THE REASON THIS SIGNATURE HAS AN ARGUMENT (round 1 finding 1).
-- This predicate is the ONE switch between the two experiences Karen has accepted -- `ForestTest.step`
-- takes `stepRest`'s stocked wood when it is true and the 20-second wave schedule when it is false --
-- and the only spec that could reach it had to write `Player.Team` to drive the true branch, which is
-- the second writer this task exists to remove. So the LIST OF TEAM NAMES may be handed in, exactly as
-- `ForestTest.boundary` takes the role, and the live call gathers it from `Players`. One loop, one
-- translator (`roleFor`), both answers reachable without a player.
function ForestTest.beaterMode(teams: { string }?): boolean
	local list = teams
	if list == nil then
		list = {}
		for _, player in ipairs(Players:GetPlayers()) do
			local team = player.Team
			table.insert(list, if team then team.Name else "")
		end
	end
	for _, team in ipairs(list) do
		if ForestTest.roleFor(team) == "beater" then
			return true
		end
	end
	return false
end

-- HOW FAR THE NEAREST SOLID THING IS from a point -- a trunk, a rock, a stand. `math.huge` for
-- nothing within `radius`.
--
-- IT IS `roomToStand`'S TEST ASKED AS A DISTANCE instead of as a yes/no, and that function's header
-- is the why: this forest is mostly ferns and leaf cards with `CanCollide = false`, so
-- `RespectCanCollide` is what separates "in the trees" from "inside a tree". Characters and animals
-- are not scenery.
--   https://create.roblox.com/docs/reference/engine/classes/WorldRoot#GetPartBoundsInRadius
function ForestTest.nearestSolid(point: Vector3, radius: number): number
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { Workspace.Terrain :: Instance }
	local boars = Workspace:FindFirstChild("Boars")
	if boars then
		table.insert(ignore, boars)
	end
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	params.MaxParts = 24
	local best = math.huge
	for _, part in ipairs(Workspace:GetPartBoundsInRadius(point, radius, params)) do
		-- THE SAME ONE RULE as `roomToStand` and `Data.groundAt` (task 158): a person is not an
		-- obstacle, and "what is a person" is answered in exactly one place.
		if Data.characterOf(part) == nil then
			local away = part.Position - point
			local gap = Vector3.new(away.X, 0, away.Z).Magnitude
			if gap < best then
				best = gap
			end
		end
	end
	return best
end

-- WHERE ONE RESTING GROUP ACTUALLY GOES: the nominal point, then rings of eight around it, and the
-- first spot that is in the trees, not inside one, and on the ground. Returns nil when the wood has
-- no such spot -- a group that cannot be put down is simply not put down, which is the same answer
-- `releaseLine` gives a line whose route cannot be computed.
-- IS THIS A SPOT A RESTING GROUP MAY GO? PURE -- five measurements in, yes or no out -- so the whole
-- rule can be asserted with hand-written numbers instead of a terrain, which is what
-- `forest_stand.spec` does. `restSpot` below is the only caller and does nothing but TAKE the five
-- measurements; the division is `MapGen.Layout`/`MapGen.Props`'s and `Horn.pieces`/`Horn.build`'s.
--
-- FIVE RULES, AND EVERY ONE OF THEM IS KAREN'S SENTENCE OR THIS TASK'S OWN MEASUREMENT:
--   `dz`         BETWEEN HER AND THE ROAD. Short of the verge and in front of where she starts; a
--                ring of the search that walked a group onto the road is not the group she asked
--                for. Karen: *"animals already there ... close to trees"*, on her side of the road.
--   `fromStart`  NOT ALREADY INSIDE HER REACH. MEASURED, this task's own first build: a group 71
--                studs from where a beater is put down was inside the one reach there was then (89
--                studs; since task 172 the guard is `SPOOK.NOTICE_STUDS`, 125), so it
--                was latched and gone on the first heartbeat before she had taken a step.
--   `terrainY`/`groundY`  ON THE GROUND AND NOT ON A CANOPY. `Runtime:spawn` places every member at
--                `world.groundAt`, which rays past `OurForest`/`Foliage` but NOT past the two
--                `Session` folders of 831 more trees (task 153 measured them). When the terrain's
--                own answer and that one disagree, that ray stopped in a tree and the sounder would
--                be dropped out of it. Either answer missing is "no spot", never "close enough".
--   `trunkGap`   IN THE TREES AND NOT INSIDE ONE. Karen: *"somewhere in bushes close to trees ect"*.
--                At least `clearStuds` from the nearest solid thing, and at most `nearTrunkStuds`
--                from it -- a spot with nothing solid near it is out in the open, which is the
--                other way to get this wrong. `nearestSolid` is why a fern does not count.
function ForestTest.restSpotOk(
	dz: number,
	fromStart: number,
	trunkGap: number,
	terrainY: number?,
	groundY: number?,
	rest,
	keepAway: number
): boolean
	if dz < rest.nearRoadStuds or dz > rest.farRoadStuds then
		return false
	end
	if fromStart < keepAway then
		return false
	end
	if terrainY == nil or groundY == nil then
		return false
	end
	if math.abs((groundY :: number) - (terrainY :: number)) > rest.canopySlackStuds then
		return false
	end
	return trunkGap >= rest.clearStuds and trunkGap <= rest.nearTrunkStuds
end

-- CAN A BEATER WALKING THIS GROUP'S LANE SEE THIS SPOT? (task 172). KAREN, 2026-10-13 ~09:20:
-- *"beaters has to see more animals when walking ... I want to see them more"*.
--
-- ONE RAY, FROM WHERE HE WILL BE STANDING WHEN IT PUTS ITS HEAD UP: `Data.laneLookPoint` is the
-- point on his own lane `REST.sightFromStuds` short of the group (45 studs, inside the 125-stud
-- notice band), at `sightEyeStuds` above the ground there; the target is the animal's shoulder.
-- Anything SOLID in between -- the same `RespectCanCollide` test `nearestSolid` and `roomToStand`
-- use, for the same measured reason (this forest is mostly ferns and leaf cards that a man sees
-- straight through) -- means the lane cannot see it.
--
-- IT IS A PREFERENCE AND NOT A RULE, and `restSpot`'s two passes are where that is decided: a wood
-- in which every legal spot happens to be screened is a wood with no animals in it, which is worse
-- than one animal behind a trunk.
--
-- THE GROUND IS ASKED AT BOTH ENDS, because the terrain here rolls: a ray from a fixed height over a
-- rise would hit the hill rather than a trunk, and that is not what is being measured. Either
-- answer missing is "cannot see it", never "close enough".
function ForestTest.restSeenFromLane(standX: number, spec, spot: Vector3, rest): boolean
	local resolved = rest or Data.REST
	local look = Data.laneLookPoint(standX, spec, spot, resolved, chosen.layout)
	local lookGround = ForestTest.terrainYAt(look.X, look.Z)
	local spotGround = ForestTest.terrainYAt(spot.X, spot.Z)
	if lookGround == nil or spotGround == nil then
		return false
	end
	local from = Vector3.new(look.X, (lookGround :: number) + (resolved.sightEyeStuds or 0), look.Z)
	local to = Vector3.new(spot.X, (spotGround :: number) + (resolved.sightTargetStuds or 0), spot.Z)
	-- THE GROUND IS A SCREEN AND THE TERRAIN IS NOT EXCLUDED (round 2's note, which was right).
	-- `nearestSolid` excludes it because "how far is the nearest trunk" is not a question about the
	-- hill; "can he see it from there" is. This wood rolls -- the two ends of this ray measured 20
	-- studs apart in height in the live place -- so a rise between the lane and the group hides the
	-- group, and a ray that flew through it would answer "seen" over a hill.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	local boars = Workspace:FindFirstChild("Boars")
	if boars then
		table.insert(ignore, boars)
	end
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local hit = Workspace:Raycast(from, to - from, params)
	-- A CHARACTER IS NOT A SCREEN, the one rule `nearestSolid` states and this borrows: a bot
	-- standing on the lane is not a reason to move a group.
	return hit == nil or Data.characterOf(hit.Instance) ~= nil
end

function ForestTest.restSpot(standX: number, spec): Vector3?
	local rest = Data.REST
	-- WHERE SHE ACTUALLY IS, NOT WHERE SHE SPAWNED (task 155, from task 154's review).
	--
	-- THIS WAS RIGHT FOR THE FIRST STOCK AND WRONG FOR THE RE-STOCK, which is the one Karen meets on
	-- her second wave. `Data.beaterStart` is where a beater is PUT DOWN, 580 studs north of the road
	-- (240 when this was written, task 162 deepened it); 15 s after she has emptied the wood she is
	-- at or past the road, that whole distance from the point -- and `REST.groups`'s last row
	-- (today `offsetX 35, northStuds 55`) is then only ~60-70 studs from her, inside
	-- the reach of the day (89 studs then; the guard is `SPOOK.NOTICE_STUDS`, 125, since task 172).
	-- So `spookNearBeaters` latched the group the heartbeat it spawned:
	-- *"a wood she has already emptied by standing in it is not a wood"*, which is the defect task
	-- 154 exists to fix, in a milder form.
	--
	-- THE LIVE POSITIONS WIN AND THE SPAWN POINT IS THE FALLBACK. `realBeaters` is empty before
	-- anybody has a body -- which is exactly when the FIRST stock happens, during `beaterStartPosition`
	-- (its own header: *"the wood would be full before she has finished falling onto the ground"*) --
	-- and then the old answer is still the right one: she is about to be standing there.
	--
	-- READ ONCE, not per candidate: five groups by 33 candidates is 165 passes through this, and
	-- `realBeaters` walks `Players:GetPlayers()`.
	local beaters = ForestTest.realBeaters()
	-- Flat and pure (`Data.beaterStart`, not the measured `beaterStartPosition`): this is a distance
	-- test and the ground does not change it, while the measured version raycasts and would be asked
	-- once per candidate.
	local start = Data.beaterStart(standX, 0, chosen.layout)
	-- THE KEEP-AWAY IS THE **NOTICE** REACH (round 1, finding 1, which was right). The question this
	-- guard asks is "could this group already be reacting to her before she has taken a step", and
	-- since task 172 the FIRST thing that happens to a group is that it notices -- at 125 studs, not
	-- at the 71 it flushes from. It was left on the flush reach while `REST.farRoadStuds`, the
	-- header above and all three spec sites had moved to the notice reach, so the only live
	-- enforcement was the weaker of the two: a ring of the search could legally answer 101 studs.
	local keepAway = Data.noticeStuds(Data.SPOOK) + rest.clearOfStartStuds
	-- ...AND NOT BEHIND THE LINE EITHER (task 168, the Director's second pass). KAREN: *"animals
	-- can't come behind beaters"*, and the dispatch: *"Nothing ever spawns or rests behind the
	-- line"*.
	--
	-- THE FIRST STOCK WAS ALREADY SAFE and the RE-STOCK was not, which is the same split the
	-- paragraph above is about: the band this searches in is measured from the ROAD (55-440 studs),
	-- the beaters start at 580, so at the first stock everything is in front of them -- but fifteen
	-- seconds after the wood is empty the line is deep in it, and a spot 440 studs from the road can
	-- be north of the front. MEASURED, a live drive: **7 animals of 25 appeared up to 31 studs behind
	-- the front**; the sweep caught them on the next tick and they ran out, but a group that has to
	-- be swept the instant it exists is a group Karen saw come from behind.
	--
	-- SO THE SWEEP'S OWN RULE DECIDES: a candidate the line would catch -- inside the band or behind
	-- it -- is refused on the first pass. `Data.sweepCatches` is the same pure function
	-- `spookNearBeaters` asks, so "behind the line" cannot be answered twice differently.
	--
	-- ...AND THE REFUSAL HAS NO FALLBACK ANY MORE (task 172). Task 168 preferred a spot in front of
	-- the line and, finding none, PLACED IT ANYWAY and let the sweep catch it -- which is exactly the
	-- animal Karen then saw come out behind the beaters a second time (*"and again no boar behing
	-- comming after beater walk"*). A group that cannot go in front of the line is simply not placed,
	-- which is the same answer `releaseLine` gives a line whose route cannot be computed.
	--
	-- WHAT THAT COSTS, SAID PLAINLY (round 2's note, which was right). On the role-at-GO path the
	-- refusal never fires: the wood is stocked on the first heartbeat of beater mode, before anybody
	-- has a body, so there is no front to be behind. On the `/beater`-typed-mid-session path, with the
	-- line already deep in the wood, groups ARE refused -- and `stepRest` re-tries every
	-- `REST.stockRetrySeconds` until the next drive puts the line back behind her and the wood in
	-- front of it. The old answer was to place them behind her anyway, which is what she saw twice.
	local sweepDepth = Data.sweepAheadStuds(Data.SPOOK, chosen.layout)
	-- TWO PASSES, AND WHAT THEY DIFFER BY IS THE SIGHTLINE (task 172): the first takes only a spot
	-- the group's own lane can SEE, the second takes any legal spot. Never the sweep rule -- that one
	-- holds in both, because "behind the line" is not a preference.
	for pass = 1, 2 do
		local wantSeen = pass == 1
		local avoidSweep = #beaters > 0
		for ring = 0, rest.searchRings do
			local tries = if ring == 0 then 1 else 8
			for step = 1, tries do
				local angle = (step - 1) * (math.pi * 2 / tries)
				local radius = ring * rest.searchStepStuds
				local at =
					Data.restPoint(standX, spec, math.cos(angle) * radius, math.sin(angle) * radius, chosen.layout)
				local dz = at.Z - Data.roadZ(at.X, chosen.layout)
				local frontZ = if avoidSweep then Data.lineFrontAt(beaters, at.X) else nil
				local swept = frontZ ~= nil and Data.sweepCatches((frontZ :: number) - at.Z, sweepDepth, Data.SPOOK)
				-- THE NEAREST REAL BEATER, or the spawn point when nobody has a body yet. `nearestBeater`
				-- answers `math.huge` for an empty list, which would pass every keep-away test, so the
				-- fallback is explicit rather than implied.
				local fromStart
				if #beaters > 0 then
					local _, gap = ForestTest.nearestBeater(at, beaters)
					fromStart = gap
				else
					fromStart = Vector3.new(at.X - start.X, 0, at.Z - start.Z).Magnitude
				end
				-- THE TERRAIN IS ASKED ONLY ONCE THE FLAT TESTS HAVE PASSED: two raycasts and an
				-- overlap query per candidate, over five rings of eight, is the one place this search
				-- could become expensive.
				local terrain = nil
				local ground = nil
				local gap = 0
				if not swept and dz >= rest.nearRoadStuds and dz <= rest.farRoadStuds and fromStart >= keepAway then
					terrain = ForestTest.terrainYAt(at.X, at.Z)
					ground = Data.groundAt(at.X, at.Z)
					if terrain ~= nil then
						gap = ForestTest.nearestSolid(
							Vector3.new(at.X, (terrain :: number) + 2, at.Z),
							rest.nearTrunkStuds
						)
					end
				end
				if not swept and ForestTest.restSpotOk(dz, fromStart, gap, terrain, ground, rest, keepAway) then
					-- BESIDE ITS OWN LANE, AND SEEN FROM IT (task 172). The lateral test is cheap and
					-- is checked in BOTH passes -- a group 200 studs off the lane it belongs to is not
					-- that lane's group whatever the trunks do -- and the ray is only cast for the
					-- spots that have already passed everything else.
					local spot = Vector3.new(at.X, terrain :: number, at.Z)
					if Data.offLaneStuds(standX, spec, spot) <= (rest.laneSideStuds or math.huge) then
						if not wantSeen or ForestTest.restSeenFromLane(standX, spec, spot, rest) then
							return spot
						end
					end
				end
			end
		end
	end
	return nil
end

-- FILLS THE WOOD. One sounder per row of `REST.groups`, resting where it is put: nothing is
-- ordered, no route is computed and no beater -- phantom or real -- is placed behind them, so the
-- Brain's own calm repertoire (`CALM.ENABLED`, task 117) is what they do until she arrives.
--
-- Returns the console line, which is the evidence: where each group went, how far that is from the
-- road, and how close the nearest trunk is.
function ForestTest.stockWood(now: number): string?
	local runtime = state.runtime
	if runtime == nil then
		return nil
	end
	local rest = Data.REST
	local standX = ForestTest.hunterStandX()
	local placed, groups = 0, 0
	local parts = {}
	for index, spec in ipairs(rest.groups) do
		local composition = boarConfig().SOUNDER.COMPOSITIONS[spec.composition]
		local wanted = if composition then Boar.compositionSize(composition, Boar.CONFIG) else 1
		-- THE CAP IS CHECKED BEFORE THE SPAWN, exactly as `ForestTest.release` checks it and for the
		-- same reason: `Runtime:spawn` ASSERTS at `maxBoars`, and an assert inside the Heartbeat
		-- kills the step rather than the spawn.
		local room = math.min(Data.MAX_BOARS, runtime:capacity()) - runtime:count()
		local at = if wanted <= room then ForestTest.restSpot(standX, spec) else nil
		if at ~= nil then
			local handles = if wanted <= 1
				then { runtime:spawn(at, "male") }
				else runtime:spawnSounder(at, wanted, rest.spreadStuds, composition)
			local made = 0
			local ids = {}
			for _, handle in ipairs(handles) do
				if handle ~= nil then
					made += 1
					table.insert(ids, handle.id)
				end
			end
			if made > 0 then
				groups += 1
				placed += made
				table.insert(state.rest, { id = string.format("rest-%d", index), ids = ids, at = at, bornAt = now })
				table.insert(
					parts,
					string.format(
						"%s %d at %+d/%+d studs (trunk %.0f)",
						spec.note,
						made,
						at.X - standX,
						at.Z - Data.roadZ(at.X, chosen.layout),
						ForestTest.nearestSolid(at + Vector3.new(0, 2, 0), rest.nearTrunkStuds)
					)
				)
			end
		end
	end
	if placed == 0 then
		return nil
	end
	state.released += placed
	return string.format(
		"the wood is stocked: %d animal(s) in %d group(s) -- %s",
		placed,
		groups,
		table.concat(parts, "; ")
	)
end

-- HOW MANY OF THE STOCKED ANIMALS ARE STILL ON THEIR FEET. Dead, despawned and crossed-out animals
-- all stop counting, which is what makes "the wood is empty" a fact rather than a timer.
function ForestTest.restAlive(): number
	local runtime = state.runtime
	if runtime == nil then
		return 0
	end
	local alive = 0
	for _, group in ipairs(state.rest or {}) do
		for _, id in ipairs(group.ids) do
			local status = runtime:statusOf(id)
			if status ~= nil and status.alive then
				alive += 1
			end
		end
	end
	return alive
end

-- SHE WALKED UP ON THEM, SO THEY GO AND THEY DO NOT STOP.
--
-- ONE PASS OVER EVERY LIVE ANIMAL IN THE WORLD, resting or in a file, because "how close is too
-- close" must have ONE answer (rule 3) -- task 153 put a copy of this inside `stepLines` when the
-- lines were the only animals there were. SINCE TASK 172 THE TEST IS `Data.encounterStage` -- the
-- band, the circle and the stand's own clock, in one pure place -- and what was a single reach is
-- its `flush` answer. An animal that reaches that stage is spooked AWAY FROM HER: `Brain:_latchFlight` takes its heading from the point handed in, so one
-- standing north of it runs SOUTH, ahead of the push and over the road, which is Karen's *"so from
-- me direction they looking they run away"*. And the fright is LATCHED -- *"it's not like they cool
-- down they spooked and run away"* -- which is the one-way rule task 150 built for a heard shot and
-- not a second panic system.
--
-- ...AND SO DOES ITS SOUNDER. The Brain spreads panic member to member on its own
-- (`SENSE.PANIC_DELAY_SECONDS`), but that spread is a plain flush and carries NO latch -- so half a
-- group would run for ever and the other half would settle in the open. One group is one decision.
--
-- ONCE PER ANIMAL, which is what `state.latched` is for: re-spooking every heartbeat would re-enter
-- `_latchFlight` sixty times a second to be refused by its own re-latch window, which is not a rule
-- anybody can read.
function ForestTest.spookNearBeaters(now: number): string?
	local runtime = state.runtime
	if runtime == nil then
		return nil
	end
	local beaters = ForestTest.realBeaters()
	if #beaters == 0 then
		return nil
	end
	-- THE FRONT, NOT A ROW OF CIRCLES (task 168, the Director's second pass). The band is
	-- `Data.sweepAheadStuds` deep in front of the line's own interpolated front and unlimited behind
	-- it, so the line SWEEPS what it reaches and leaves nothing behind -- which the circle did not:
	-- a live drive left 13 of 27 animals standing where they were while the line walked past them.
	-- Both numbers and both rules are `src/shared/ForestTest`'s, pure and asserted there.
	--
	-- THE POINT IT RUNS FROM IS STILL A REAL BODY -- the nearest beater -- and never the interpolated
	-- front: `Brain:_latchFlight` takes the animal's heading away from the point it is handed, and the
	-- note's one requirement for this stimulus is that it be somewhere somebody is standing. The
	-- front decides WHO is flushed; a man decides WHICH WAY.
	state.latched = state.latched or {}
	state.noticedAt = state.noticedAt or {}
	local sent = {}
	local looked = {}
	for _, handle in ipairs(runtime:boars()) do
		if state.latched[handle.id] ~= true then
			local at = handle.position()
			local frontZ = Data.lineFrontAt(beaters, at.X)
			-- SOUTH IS THE ROAD AND IS A SMALLER z (`Data.beaterStart` is `roadZ + north`), so an
			-- animal IN FRONT of the line has the smaller z and `ahead` is positive.
			local ahead = if frontZ ~= nil then (frontZ :: number) - at.Z else math.huge
			local from, gap = ForestTest.nearestBeater(at, beaters)
			-- WHICH STAGE THIS ANIMAL HAS REACHED, decided in ONE pure place (task 172): the band,
			-- the circle and the clock are all `Data.encounterStage`'s, so this loop measures and
			-- obeys and decides nothing.
			local since = if state.noticedAt[handle.id] ~= nil then now - state.noticedAt[handle.id] else nil
			local stage = Data.encounterStage(ahead, gap, since, Data.SPOOK, chosen.layout)
			if from ~= nil and stage == "flush" then
				table.insert(sent, { id = handle.id, from = from, gap = gap, ahead = ahead })
			elseif from ~= nil and stage == "notice" and state.noticedAt[handle.id] == nil then
				table.insert(looked, { id = handle.id, from = from, gap = gap })
			end
		end
	end

	-- THE STAND, BEFORE ANY OF THEM RUN (task 172). KAREN, 2026-10-13 ~09:20: *"I want to see how
	-- they stand and then start to run"*.
	--
	-- THE WHOLE SOUNDER LOOKS UP, exactly as the whole sounder leaves: a group is one decision, which
	-- is this function's own rule for the flush and the reason it is written once here. The clock
	-- starts for every member the tick the first of them notices, so the group breaks together.
	local alertFor = Data.alertSeconds(Data.SPOOK)
	local stood = 0
	for _, row in ipairs(looked) do
		local ids = { row.id }
		local sounder = runtime:sounderOf(row.id)
		if sounder ~= nil then
			ids = sounder.memberIds
		end
		for _, id in ipairs(ids) do
			-- THE CLOCK STARTS ONLY WHEN THE LOOK WAS ACCEPTED (round 2's note, which was right).
			-- `Brain:notice` refuses anything that is not IDLE, and a walking file is never IDLE --
			-- so starting the clock either way turned the stage into an invisible two-second DELAY
			-- for every animal already on the move, which is a change to the hunter's drive that
			-- nobody asked for. An animal that cannot stand is simply not in the stage: it reaches
			-- `flush` through the band or the circle, exactly as it did before this task.
			if state.noticedAt[id] == nil and state.latched[id] ~= true then
				if runtime:notice(id, row.from, alertFor) then
					state.noticedAt[id] = now
					stood += 1
				end
			end
		end
	end
	if stood > 0 then
		state.noticed = (state.noticed or 0) + stood
	end
	local parts = {}
	for _, row in ipairs(sent) do
		-- THE WHOLE SOUNDER, from the same point, so the group leaves as a group.
		local ids = { row.id }
		local sounder = runtime:sounderOf(row.id)
		if sounder ~= nil then
			ids = sounder.memberIds
		end
		local went = 0
		for _, id in ipairs(ids) do
			if state.latched[id] ~= true and runtime:spook(id, row.from, true) then
				state.latched[id] = true
				went += 1
			end
		end
		state.latched[row.id] = true
		if went > 0 then
			state.flushed = (state.flushed or 0) + went
			table.insert(
				parts,
				string.format(
					"%s at %.0f studs (%.0f m), %.0f ahead of the front, took %d with it",
					row.id,
					row.gap,
					row.gap * Data.SPOOK.METRES_PER_STUD,
					row.ahead,
					went
				)
			)
		end
	end
	-- THE STAND IS REPORTED WHETHER OR NOT SOMETHING ELSE WENT ON THE SAME TICK (round 1's note,
	-- which was right): one group bolting while another stands is exactly the tick the proof wants
	-- to see, and the stand used to be printed only when nothing had bolted.
	local stand = if stood > 0
		then string.format(
			"%d animal(s) stood and looked (%.0f s before they go) -- %d so far",
			stood,
			alertFor,
			state.noticed
		)
		else nil
	if #parts == 0 then
		return if stand ~= nil then "a beater was noticed: " .. stand else nil
	end
	local line = string.format("a beater spooked %s -- %d latched so far", table.concat(parts, "; "), state.flushed)
	return if stand ~= nil then line .. "; and " .. stand else line
end

-- ONE TICK OF BEATER MODE: whether the wood needs filling. `spooked` is what
-- `ForestTest.spookNearBeaters` said this step -- it is passed IN rather than asked for again,
-- because `step` has already run that pass for both modes and running it twice would latch
-- nothing and cost a scan of every animal in the world. Returns the one line the boot prints.
function ForestTest.stepRest(now: number, spooked: string?): string?
	if state.runtime == nil then
		return nil
	end
	-- WHAT TO DO ABOUT THE STOCK THIS TICK is `Data.stockStep`'s, pure, so the rule can be asserted
	-- without a runtime (round 3's finding: `stepRest` returns on its first line in the spec place,
	-- so a case that called it could not fail). This function takes the measurements and obeys.
	local decision = Data.stockStep(state.restStocked == true, state.restTriedAt, now, Data.REST)
	if decision == "stock" then
		-- NOTHING HAS BEEN PUT DOWN FOR THIS DRIVE: fill it now, on the first heartbeat after she
		-- becomes a beater. Level-triggered rather than called from the boot, so a role set before the
		-- runtime existed, a `/beater` typed mid-session and a respawn all end in the same place.
		--
		-- THE LATCH IS SET WHEN SOMETHING WAS ACTUALLY PLACED (round 2's note, which was right), not
		-- when the attempt was made -- `stockStep` answers "wait" until the retry clock is up, and
		-- the latch below is the only thing that ever makes it answer "done".
		state.restTriedAt = now
		local stocked = ForestTest.stockWood(now)
		if stocked ~= nil then
			state.restStocked = true
			return stocked
		end
		return spooked
	end
	-- ...AND IT IS NEVER RE-STOCKED (task 172). KAREN, 2026-10-13 ~09:25: *"and again no boar behing
	-- comming after beater walk"*. The re-stock measured its groups from the ROAD while the line was
	-- already deep in the wood, so the deep rows had nowhere to go that was in front of anybody --
	-- `REST`'s own header has the measurement. A wood is beaten once; when it is empty it stays empty
	-- for this drive.
	return spooked
end

-- A NEW DRIVE, AND THE WOOD IS A NEW WOOD (round 2, finding 1, which was right).
--
-- *"If the wood empties, it stays empty for this drive"* is the dispatch's own sentence, and until
-- this function existed the code said DRIVE and meant SESSION: `state.restStocked` was written false
-- in exactly one place, `ForestTest.start`'s reset, and the boot calls `start` once per server. So a
-- beater who cleared the wood in drive 1 walked 580 studs of empty wood in every drive after it --
-- task 154's founding defect in a new form, and the behaviour that used to cover the boundary (the
-- 15-second re-stock) is the one this task archived.
--
-- IT IS CALLED ON THE `Assigning` EDGE, which is the boundary the boot already listens to for the
-- report window, and it resets exactly the four things that are ABOUT ONE DRIVE'S WOOD: what was
-- stocked, whether it has been, which animals have been latched, and which have been noticed. The
-- COUNTERS (`flushed`, `noticed`, `released`) are the session's and are not touched -- they are what
-- `stats()` publishes and what the `[rest]` lines count up.
function ForestTest.newDrive()
	state.rest = {}
	state.restStocked = false
	state.restTriedAt = nil
	state.latched = {}
	state.noticedAt = {}
	state.restTrace = {}
	-- ...AND A NEW DRIVE IS A NEW DEER (task 239). Karen: *"we need all a time in drive deer"* -- so
	-- the guarantee is spent per DRIVE, which means it is handed back here and nowhere else, exactly
	-- as `Match.Phase` hands `deerReleased` back at its own drive boundary. The ordinal is cleared
	-- rather than redrawn: `releaseLine` draws it on this drive's first wave, where `state.rng`
	-- certainly exists.
	state.driveWave = 0
	state.deerWave = nil
	state.deerDone = false
end

-- ---------------------------------------------------------------- CHOOSING A LAYOUT (task 179)
--
-- KAREN, 2026-10-13: *"not all a time same place hunters standing and not the same terrain for
-- beaters"*. One layout per drive, dealt from a bag, never the same one twice running.
--
-- THIS MODULE IS THE ONE WRITER OF THAT CHOICE (design 5.1). It deals, it publishes the name for
-- the clients, and it swaps the boar field that goes with it. `ForestTestBoot` says WHEN -- it owns
-- nothing and decides nothing -- and the client reads one string and never derives.

-- THE DIRECTOR'S OVERRIDE, PARSED. PURE, and `startRole`'s shape exactly: a leading slash, any
-- spacing and any case are all accepted, because the thing on the other end is a human typing into
-- a Studio property field. A name the table does not know answers nil, which the caller turns into
-- one console line and a normal deal -- never a crash and never a layout-less drive.
function ForestTest.forcedLayout(value: any): string?
	if typeof(value) ~= "string" then
		return nil
	end
	local word = string.lower((string.gsub(value :: string, "%s", "")))
	if string.sub(word, 1, 1) == "/" then
		word = string.sub(word, 2)
	end
	return if Data.layoutNamed(word) ~= nil then word else nil
end

-- PUBLISHES THE LIVE NAME FOR THE CLIENTS. The ONE writer of that attribute.
--
-- The host is a Rojo-owned `Configuration` that is a CHILD of the shared module
-- (`src/shared/ForestTest/Live.model.json`), which is `Flags.state`'s own shape and for the reason
-- that file writes down: it is found through the module instance and never by searching
-- `ReplicatedStorage`, so one file means one instance and Rojo owns both.
--
-- A MISSING HOST IS A CONSOLE LINE, NOT AN ERROR. `Flags.publish` errors on its missing host because
-- a server with no flags is a broken build; here the only consequence is that the hunter's MAP does
-- not draw -- which `MapUi.geometryFor` already handles by drawing nothing and saying so. A drive
-- that refuses to start over a map panel would be worse than a drive with no map.
function ForestTest.publishLayout(name: string)
	local host = DataModule:FindFirstChild(Data.LIVE_NAME)
	if host == nil then
		warn(
			string.format(
				"[ForestTest] cannot publish layout=%s: ReplicatedStorage.ForestTest.%s is missing "
					.. "(src/shared/ForestTest/Live.model.json). The hunter's map will not draw.",
				name,
				Data.LIVE_NAME
			)
		)
		return
	end
	host:SetAttribute(Data.LAYOUT_ATTRIBUTE, name)
end

-- PUTS THE LIVE LAYOUT'S FIELD ON A RUNTIME -- the bounds, the exit line and the ground height. The
-- ONE place that writes a runtime's field, so "which field is this world on" cannot be answered twice
-- differently (round 1, finding 2). Returns whether it wrote one, so a spec and the console can say.
function ForestTest.applyField(runtime): boolean
	if runtime == nil or runtime.setField == nil then
		return false
	end
	runtime:setField(Data.fieldFor(chosen.layout))
	return true
end

-- EVERYTHING THAT HAS TO HAPPEN WHEN THE GROUND MOVES, in one place and in this order (design 6.5
-- steps 1 and 2). Steps 3 to 8 are already per-drive and are listed there; nothing here repeats
-- them.
local function promote(name: string, source: string)
	local layout = Data.layoutNamed(name)
	if layout == nil then
		return
	end
	chosen.layout, chosen.name, chosen.source = layout, name, source
	ForestTest.publishLayout(name)
	chosen.published = true
	-- THE PREVIOUS LAYOUT'S ANIMALS GO, AND THEY GO BEFORE THE FIELD IS SWAPPED. `retire` ends this
	-- module's own waves and files; `runtime:clear()` takes every body. A boar left standing would
	-- keep the field it was born with (`Runtime:setField`'s own header) AND would be standing 500
	-- studs from the drive that is about to start.
	ForestTest.retire(os.clock())
	local runtime = state.runtime
	if runtime ~= nil then
		runtime:clear("layoutChanged")
		ForestTest.applyField(runtime)
	end
	-- THE LIVE FILES GO WITH THE BODIES (round 1, note 2). `retire` drops rows from `state.active`;
	-- `state.lines` is `newDrive`'s to clear, and `promote` does not call it -- so after
	-- `runtime:clear` the files held ids of destroyed bodies.
	state.lines = {}
	-- THE WOOD IS A NEW WOOD. `newDrive` clears this latch on the `Assigning` edge anyway; doing it
	-- here as well is what makes a FORCED mid-session layout change (the Director setting
	-- `DHForestLayout` and restarting) stock the new layout's lanes rather than sit on the old
	-- drive's latch.
	state.restStocked = false
	state.restTriedAt = nil
	print(
		string.format(
			"[ForestTest] layout=%s (%s): %d stands %d apart, centre (%d, %d), exit %d",
			name,
			source,
			layout.standCount,
			layout.standSpacing,
			layout.centre.X,
			layout.centre.Z,
			Data.exitZOf(layout)
		)
	)
end

-- WHICH LAYOUT THIS DRIVE IS ON, dealing one if this drive has not been dealt yet. THE ONE
-- PROMOTER.
--
-- IDEMPOTENT PER DRIVE NUMBER, and that is load-bearing rather than tidy: `Match` reads the markers
-- once a second while it is `Waiting`, so a promoter that dealt on every call would change the
-- ground under a hunter who is standing on it. `chosen.drive` is the key and nothing else advances
-- it.
--
-- DRIVE 0 AND DRIVE 1 ARE ONE KEY. `Match.driveNumber()` is 0 while `Waiting`, so without the
-- `max(1, ...)` the first layout would be dealt for the waiting room and a SECOND one dealt the
-- instant the first real drive began -- two layouts before anybody had played one.
--
-- THE OVERRIDE DOES NOT ADVANCE THE ROTATION. A forced drive does not write `chosen.cycle`, so
-- clearing `DHForestLayout` returns the cycle to exactly where it left off.
function ForestTest.layoutForDrive(driveNumber: number?, override: any): string
	local key = math.max(1, driveNumber or 0)
	if chosen.drive == key then
		return chosen.name
	end
	local forced = ForestTest.forcedLayout(override)
	local name, source
	if forced ~= nil then
		name, source = forced, "override"
	else
		if override ~= nil and typeof(override) == "string" then
			-- A NAME NOBODY KNOWS IS ONE LINE AND A NORMAL DEAL, never a crash: the Director typing
			-- "clearing" into a Studio field must not be able to stop a playtest.
			warn(
				string.format(
					"[ForestTest] %s=%s is not a layout (have: %s); dealing normally",
					Data.LAYOUT_OVERRIDE_ATTRIBUTE,
					tostring(override),
					table.concat(Data.layoutNames(), ", ")
				)
			)
		end
		-- THE ROTATION (task 193, Karen: *"each time person will be in new place ... then loop it
		-- again"*). `chosen.cycle` and not `chosen.name` is what it steps from, because `promote`
		-- writes `name` for a FORCED drive too -- so advancing from `name` would resume the cycle at
		-- the forced place (Reviewer, round 1, note 6). Nil means the cycle has not started and
		-- `nextLayout` answers place 1.
		name = Data.nextLayout(chosen.cycle)
		chosen.cycle = name
		source = "rotation"
	end
	chosen.drive = key
	if name ~= chosen.name then
		promote(name, source)
	else
		-- THE SAME LAYOUT AGAIN (an override repeated, or a one-name table). Nothing is torn down --
		-- the ground has not moved -- but the NAME IS STILL PUBLISHED, unconditionally, and that is
		-- round 1's finding 4: `promote` was the only publisher and it runs only when the layout
		-- MOVES, so a session whose first deal happened to equal the starting name
		-- (`DHForestLayout = road`, or a bag that deals the default first) wrote no attribute at
		-- all -- and `MapUi.geometryFor` answers nil for a nil name, so the hunter had NO MAP for
		-- the whole session.
		--
		-- UNCONDITIONAL AND NOT LATCHED, because a latch answers "has this process ever said it"
		-- when the question is "does the attribute say what is true". Writing the same string again
		-- fires no `AttributeChanged` on the engine's side, so this costs the clients nothing and
		-- the published name cannot drift from the live one however it was cleared.
		ForestTest.publishLayout(name)
		-- The LINE is still once per choice: a print every drive that said nothing had changed would
		-- bury the one that did.
		if not chosen.published then
			chosen.published = true
			print(
				string.format(
					"[ForestTest] layout=%s (%s): %d stands %d apart, centre (%d, %d), exit %d",
					name,
					source,
					chosen.layout.standCount,
					chosen.layout.standSpacing,
					chosen.layout.centre.X,
					chosen.layout.centre.Z,
					Data.exitZOf(chosen.layout)
				)
			)
		end
		-- ...and the SOURCE is always recorded, because "this drive was forced" is exactly the fact
		-- a report must not lose.
		chosen.source = source
	end
	return chosen.name
end

-- WHAT EVERY STOCKED GROUP IS DOING, as one line each. The proof reads this: how far the nearest
-- beater is, how fast they are moving, and whether they are moving AWAY from her.
--
-- "AWAY" IS MEASURED AND NOT ASSUMED: the dot of this step's movement with the direction away from
-- the nearest beater, +1 for straight away and -1 for straight at her. The previous position is
-- kept here rather than asked of the Brain, because what a hunter sees is where the body went and
-- not what it was ordered to do.
function ForestTest.restReport(_now: number): { string }
	local runtime = state.runtime
	if runtime == nil then
		return {}
	end
	local beaters = ForestTest.realBeaters()
	state.restTrace = state.restTrace or {}
	local out = {}
	for _, group in ipairs(state.rest or {}) do
		local alive, speedSum, awaySum, counted, nearest = 0, 0, 0, 0, math.huge
		-- `walk` COUNTS ONLY THE WALK-UP PASS, and the name says so: the horn latches an animal
		-- through `Runtime:hearHorn` without this module ever seeing it, so a group running at
		-- `RUN_SPEED` with `walk=0` is the horn's work and the mood column is what proves it ran.
		local dzSum, walked = 0, 0
		-- WHAT MOOD THEY ARE IN, counted (task 154). "They are resting" and "they are walking at 4.5
		-- studs/s" are two different claims and the first one is the one Karen asked for, so the
		-- state the Brain is actually in goes in the line beside the speed.
		local states = {}
		for _, id in ipairs(group.ids) do
			local status = runtime:statusOf(id)
			if status ~= nil and status.alive then
				alive += 1
				states[status.state] = (states[status.state] or 0) + 1
				speedSum += status.speed
				dzSum += status.position.Z - Data.roadZ(status.position.X, chosen.layout)
				if state.latched[id] == true then
					walked += 1
				end
				local at, gap = ForestTest.nearestBeater(status.position, beaters)
				if gap < nearest then
					nearest = gap
				end
				local was = state.restTrace[id]
				if was ~= nil and at ~= nil then
					local moved = Vector3.new(status.position.X - was.X, 0, status.position.Z - was.Z)
					local away = Vector3.new(status.position.X - at.X, 0, status.position.Z - at.Z)
					if moved.Magnitude > 0.05 and away.Magnitude > 0.05 then
						awaySum += moved.Unit:Dot(away.Unit)
						counted += 1
					end
				end
				state.restTrace[id] = status.position
			end
		end
		if alive > 0 then
			local moods = {}
			for mood, count in pairs(states) do
				table.insert(moods, string.format("%s*%d", tostring(mood), count))
			end
			table.sort(moods)
			table.insert(
				out,
				string.format(
					"%s alive=%d walk=%d %s dz=%.0f speed=%.1f nearest beater=%s away=%s",
					group.id,
					alive,
					walked,
					table.concat(moods, ","),
					dzSum / alive,
					speedSum / alive,
					if nearest < math.huge then string.format("%.0f", nearest) else "none",
					if counted > 0 then string.format("%+.2f", awaySum / counted) else "--"
				)
			)
		end
	end
	return out
end

-- ---------------------------------------------------------------- the loop

function ForestTest.start(runtime, now: number)
	state.runtime = runtime
	-- THE FIELD THE CHOSEN LAYOUT NEEDS, AND THIS IS THE FIRST DRIVE'S ONLY CHANCE AT IT (round 1,
	-- finding 2). `promote` swaps the field on the runtime, but the FIRST deal happens inside
	-- `Match.start`'s own first marker read -- which the boot runs BEFORE this function, so
	-- `state.runtime` was still nil and the swap was skipped. The first drive of every session then
	-- ran a non-road layout against the ROAD's field: on the ride that is an exit line 223 studs
	-- NORTH of the hunters, and on the edge the spawns are out of bounds outright.
	--
	-- SINCE TASK 193 THE FIRST DEAL IS THE ROAD (`LAYOUT_ORDER[1]`, Karen's place 1), so the first
	-- drive of a session no longer hits that case -- but the call stays, because a FORCED first
	-- drive (`DHForestLayout = ride`) still does, and because the second drive onwards always did.
	-- Task 179's finding was that the swap was skipped, not that it was skipped only once.
	ForestTest.applyField(runtime)
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
	-- TASK 153: how many animals a real beater has walked up to, and the line the console gets.
	state.flushed = 0
	state.flushLine = nil
	-- TASK 154: the resting groups this world was stocked with, and when the wood last went empty.
	-- `rest` holds one row per group that was actually placed; `latched` remembers which animals
	-- have already been sent, so one walk past a sounder is one spook and not one per heartbeat.
	-- TASK 172: the wood is stocked ONCE PER DRIVE and never re-stocked inside one, so what is
	-- remembered is not "when did it go empty" but "has it been stocked for this drive" -- plus which
	-- animals have been latched and which have been noticed (`SPOOK.ALERT_SECONDS` runs from there).
	-- Karen, 2026-10-13: *"and again no boar behing comming after beater walk"* -- the re-stock was
	-- the one source task 168 left open. ONE function resets all of it, and the boot calls the same
	-- one on every drive boundary, so a server start and a new drive cannot drift apart.
	ForestTest.newDrive()
	state.noticed = 0
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
			local dz = (centre :: Vector3).Z - Data.roadZ((centre :: Vector3).X, chosen.layout)
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
						then string.format(
							"dz=%.0f gap=%.1f",
							at.Z - Data.roadZ(at.X, chosen.layout),
							(at - centre).Magnitude
						)
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
		-- WHO HAS BEEN WALKED UP ON, BEFORE ANYTHING ELSE IS DECIDED (task 154). It runs in BOTH
		-- modes and over every live animal, so a beater meeting a scheduled line and a beater
		-- meeting a resting sounder get the same rule -- see `ForestTest.spookNearBeaters`.
		local spooked = ForestTest.spookNearBeaters(now)
		ForestTest.stepLines(now)
		-- ONE LINE PER FLUSH (task 153), through the channel this module already answers on: the
		-- boot prints whatever `step` returns, and "the beater had no visible effect" is the kind of
		-- claim that needs a number beside it.
		local flush = ForestTest.takeFlushLine() or spooked
		-- BEATER MODE HAS NO SCHEDULE (task 154). Karen walked the then 240 studs to the road in
		-- about sixteen seconds and the first wave was still four seconds away: *"didn;t see any animals
		-- probably need to wait 10s ?"*. So nothing is released on a timer while she is a beater --
		-- the wood is already full, and `stepRest` is what fills and re-fills it. A HUNTER's world
		-- is untouched: he stands still and the drive comes to him, which is what a schedule is for.
		if ForestTest.beaterMode() then
			return ForestTest.stepRest(now, spooked) or flush
		end
		if now < state.nextWaveAt then
			return flush
		end
		state.nextWaveAt = now + Data.SCHEDULE.intervalSeconds
		state.waveIndex += 1
		-- ...AND THIS DRIVE'S OWN COUNT (task 239), which is what the deer ordinal is drawn against.
		-- Two counters and not one: `waveIndex` numbers the console lines for the whole session and
		-- must not restart, and an ordinal drawn against it would mean "wave 3 of the session".
		state.driveWave = (state.driveWave or 0) + 1
		return ForestTest.releaseLine(now) or flush
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
		local dz = at.Z - Data.roadZ(at.X, chosen.layout)
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
		local dz = at.Z - Data.roadZ(at.X, chosen.layout)
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
	local crossing = Vector3.new(crossX, chosen.layout.centre.Y, Data.roadZ(crossX, chosen.layout))
	local startZ = crossing.Z + lineData.spawnNorthStuds
	local start = Vector3.new(crossX, Data.groundAt(crossX, startZ) or chosen.layout.centre.Y, startZ)
	-- PAST THE DESPAWN LINE, NOT UP TO IT, and that was a measured bug: the route ended at
	-- `EXIT_Z + 20`, which is twenty studs NORTH of the line `Brain:_outcome` despawns at -- so every
	-- line walked its whole route, arrived, and then stood on the last waypoint for ever. The stuck
	-- counter showed it as a cluster of animals all going still at 134-152 s, which is exactly how
	-- long a 600-stud route takes. Ending ten studs PAST the line means the last thing they do is
	-- cross it, which is Karen's *"once they in another side of road they run away"*.
	local exitPoint = Vector3.new(crossX, chosen.layout.centre.Y, Data.exitZOf(chosen.layout) - 10)

	local count = rng:NextInteger(4, 9)
	local lines = if rng:NextNumber() < lineData.twoLineChance then 2 else 1
	local pace = ForestTest.paceFor(rng:NextNumber(), lineData.paceMix)
	local speed = ForestTest.paceSpeed(pace, boar)

	-- IS THIS WAVE THE DRIVE'S RED DEER (task 239)? The whole decision, and every part of it that is
	-- about the ANIMAL is asked of the animal's owner:
	--   `Runtime:deerAllowed` is `MAX_GROUPS_ALIVE`, the same answer `spawnSounder`'s own door gets.
	--   `Boar.deerComposition` is whether (`CHANCE_PER_RELEASE`, or the drive's ask) and who.
	-- The only thing decided here is WHEN, which is this drive's own business -- see `deerWaveOf`.
	--
	-- THE ORDINAL IS DRAWN ON THE DRIVE'S FIRST WAVE and not in `newDrive`, because `newDrive` is
	-- also called by a spec and by `start`, where `state.rng` is not yet this drive's.
	if state.deerWave == nil then
		state.deerWave = ForestTest.deerWaveOf(rng:NextNumber(), ForestTest.wavesPerDrive())
	end
	local composition = nil
	-- WAS IT THE DRIVE'S OWN, OR ONE OF THE EXTRAS `CHANCE_PER_RELEASE` BUYS? Kept so the console
	-- line can say which, because a reader counting deer in a playtest has to be able to tell the
	-- guarantee from the dial -- the first run after this change released a guaranteed hind-and-calf
	-- on wave 1 and a chance stag-and-hinds on wave 10, and without this they read identically.
	local guaranteed = false
	-- A VIEW WITHOUT THE DOOR IS A WORLD WITH NO DEER, not an error: `forest_stand.spec` drives this
	-- module with a hand-written runtime, and an older one has no `deerAllowed`.
	if type(runtime.deerAllowed) == "function" and runtime:deerAllowed() then
		guaranteed = ForestTest.deerWanted(state.driveWave or 0, state.deerWave, state.deerDone == true)
		composition = Boar.deerComposition(rng:NextNumber(), rng:NextNumber(), boar, guaranteed)
	end
	if composition ~= nil then
		-- A COMPOSITION IS ALSO THE SIZE, read through the one function that knows what a
		-- composition weighs -- `Runtime:spawnSounder`'s own line, for its own reason.
		count = Boar.compositionSize(composition, boar)
		-- ONE FILE. A deer group is one to three animals and `SPECIES.reddeer.RELEASE.FORMATION` is
		-- `"column"`; splitting two animals into two parallel files is not a column, and
		-- `Boar.compositionFormation` is what declares that for the sounder path.
		lines = 1
	end

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
	-- ...AND THE COMPOSITION IS HANDED IN SINCE TASK 239. `nil` is every wave this world released
	-- before it -- a sow and her young drawn from `SOUNDER.MAKEUP` -- and a deer group names its own
	-- kinds, so the same function answers both and this file never writes the word "stag".
	local kinds = Boar.sounderKinds(count, rolls, boar, composition)

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
	-- THE MARCH IS THE ANIMAL OWNER'S FACT (task 239): `Boar.MARCH_RANK` ranks the deer as well as
	-- the boars, so a hind leads her calf and a harem's stag walks last. Without it `Line.order`'s
	-- own default knows three words and all three deer tie at the unknown rank.
	local plans = Line.split(Line.order(order, Boar.MARCH_RANK), lines)

	local groups = {}
	for which, plan in ipairs(plans) do
		groups[which] = {}
		local lateral = routes[which].lateral
		for rank, member in ipairs(plan) do
			local at = start - toward * ((rank - 1) * lineData.spacingStuds) + Vector3.new(lateral, 0, 0)
			local ground = Data.groundAt(at.X, at.Z)
			local handle = runtime:spawn(Vector3.new(at.X, (ground or chosen.layout.centre.Y) + 2, at.Z), member.kind)
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
	-- THE GUARANTEE IS SPENT ONLY ONCE A GROUP IS ON THE GROUND (task 239). Every early return
	-- above -- no route, nobody placed -- leaves the latch alone, so a deer wave that could not be
	-- released hands the drive's one group to the next wave rather than losing it. `deerWanted`'s
	-- `>=` is the other half of that.
	-- ...AND ANY GROUP SPENDS IT, not only the guaranteed one: a drive that has already shown her a
	-- stag has met *"I want to see a deer"*, and asking again on the ordinal would put a second
	-- group out for no reason. `MAX_GROUPS_ALIVE` caps what is ALIVE at once; this caps the ASK.
	if composition ~= nil then
		state.deerDone = true
	end
	return string.format(
		-- MADE *OF SPAWNED*, because the two can only differ if an animal was left behind by a line
		-- that was not released -- which is the orphan the Reviewer found and this round closed. A
		-- wave that reads "5 of 5 animal(s) in 1 of 2 line(s)" is the case: one route failed, one
		-- line was released, and nobody was spawned for the line that could not be walked.
		-- ...AND WHAT WAS IN IT, when it was not boars (task 239): the console is where Karen and
		-- the Director see that the drive's deer actually went, and "6 animals" does not say it.
		"line %d: %d of %d animal(s) in %d of %d line(s) at a %s, crossing %+d studs from the stand%s",
		state.waveIndex,
		made,
		#members,
		lines,
		asked,
		pace,
		offset,
		if composition ~= nil
			then string.format(
				" -- RED DEER (%s), %s, on this drive's wave %d",
				table.concat(kinds, "+"),
				if guaranteed then string.format("the drive's own, due on wave %d", state.deerWave or 0) else "an extra",
				state.driveWave or 0
			)
			else ""
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
		-- A BEATER WALKING UP ON A FILE IS THE SAME RULE AS A BEATER WALKING UP ON A RESTING GROUP,
		-- AND THERE IS NOW ONE PLACE THAT APPLIES IT: `ForestTest.spookNearBeaters`, which runs over
		-- every live animal in the world once per step, before this loop. Task 153 put a copy of it
		-- here because the lines were the only animals there were; task 154 stocks the wood with
		-- resting sounders as well, and two copies of "how close is too close" is two answers.
		--
		-- WHAT THAT PASS DOES FOR A FILE IS UNCHANGED IN KIND AND CHANGED IN DEGREE: an ordered
		-- animal returns from `Brain:step` before the pace clamp and before every mood (task 127: "a
		-- line crossing a road does not stop to look at the edge"), so being marked a `driver` in
		-- `boarThreats` changes nothing for an animal walking a trail -- MEASURED in this place: she
		-- walked to within 8.9 studs of a file and every member kept its ordered walk at 4.5
		-- studs/s. Only a flight takes an animal out of a file, and the pass asks for one. It now
		-- asks at `SPOOK.BEATER_STUDS` (20 m since task 172) instead of `PACE.DRIVER_RUN_STUDS`
		-- (25 studs, 7 m),
		-- and it asks for the LATCH -- Karen: *"it's not like they cool down they spooked and run
		-- away"*. `Line.stillInFile` then drops the flying animal out of the file below, as it
		-- always has.
		for _, member in ipairs(line.members) do
			local status = runtime:statusOf(member.id)
			if status ~= nil and status.alive then
				local wound = runtime:woundOf(member.id)
				local already = line.gone[member.id] == true
				local flying = runtime:flying(member.id)
				local hurt = wound ~= nil and wound.severity ~= nil and wound.severity ~= "healthy"
				local dz = status.position.Z
					- (Data.roadZ(status.position.X, chosen.layout) - Data.SHAPE.halfWidthStuds)
				local stays = Line.stillInFile(already, flying, hurt, dz)
				if stays then
					table.insert(live, { id = member.id, kind = member.kind, status = status })
				else
					-- ...AND THE ONE THAT HAS JUST CROSSED RUNS AWAY (task 139 round 3, the
					-- Reviewer's finding 1). Karen: *"and they run away when cross the road"*. See
					-- `Line.crossedOut`: of the four ways out of the file this is the only one that
					-- gets a shove, and it gets it ONCE, on the step it leaves -- a flying animal is
					-- already running, a hurt one is the Brain's cripple, and an animal already
					-- `gone` was shoved on its own step.
					--
					-- THE THING IT RUNS FROM IS THE DRIVE, which is behind it: the point handed to
					-- `spook` is `LINE.runAwayFromStuds` north of the animal, so `Brain:_latchFlight`
					-- takes a heading south, toward `field.exitZ`, where it despawns.
					if Line.crossedOut(already, flying, hurt, dz) then
						runtime:spook(member.id, status.position + Vector3.new(0, 0, lineData.runAwayFromStuds))
					end
					line.gone[member.id] = true
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
		-- `Runtime:flying` asks the Brain. SINCE TASK 139 IT IS ALSO FILTERED OUT above and never
		-- rejoins, so these two guards can no longer be true for a member of `live`; they are kept
		-- because they are the ONE OWNER boundary this file has -- the drive must not order an
		-- animal the Brain is flying, whoever adds the next way into `live`.
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
		if not line.checked and at.Z - Data.roadZ(at.X, chosen.layout) <= lineData.checkWithinStuds then
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
			-- ...AND THE ONE IN FRONT HAS TO BE IN THE LINE (round 2, the Reviewer's note). When
			-- `live` was filtered on alive alone a bolting animal kept its rank, and handing its arc
			-- position down as "the one in front" regulated the file against an animal that was, two
			-- dozen lines above, declared not to be in the line any more. Task 139's filter is what
			-- made that impossible; this is the same boundary, kept for the same reason.
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
							Vector3.new(line.crossing.X, chosen.layout.centre.Y, Data.exitZOf(chosen.layout) - 10)
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

-- `ForestTest.spawnPosition` IS ARCHIVED (task 157, rule 7:
-- `backups/2026-10-11_task157_forest_roles_and_placement.txt`). It put a hunter on the road at the
-- default stand, and the real drive does that now: `ForestTest.Markers` builds a marker part per
-- stand at measured ground and `Match.Body.place` -- the one writer of where a character stands --
-- puts her on the one `ForestTest.standIndexFor` names. It is archived rather than retained because
-- the thing it measured is measured in two better places already; `drive`/`driveIndexAt` above are
-- retained instead, because their arithmetic has a spec and this had none.

-- WHICH STAND A HUNTER GETS, from her index within the team. PURE.
--
-- CENTRE-OUT -- 5, 4, 6, 3, 7, 2, 8, 1, 9 -- AND THE FIRST ANSWER IS THE WHOLE POINT: a solo hunter
-- gets stand 5, which is `Data.PICK.defaultIndex`, which is the x `ForestTest.hunterStandX()` aims
-- every wave at. `Body.placementFor` would hand her `posts[1]` -- 600 studs west of where the drive
-- is pushing -- and whether she ever got a crossing would be luck again, which is the defect task
-- 123 round 8 measured and fixed.
--
-- IT WRAPS, like `placementFor` does (`% #posts`), so a tenth hunter shares stand 5. With
-- `MAX_PLAYERS` 16 and a balanced split there are at most 8 shooters, so the wrap is unreachable in
-- production -- and asserted anyway, because unreachable is a claim and not a guarantee.
-- Pattern: Quake III's `SelectSpawnPoint` family -- the mode chooses AMONG the points the world
-- placed (docs/design/forest-drive.md section 11.5).
function ForestTest.standIndexFor(index: number): number
	local count = chosen.layout.standCount
	local zero = (math.max(1, math.floor(index)) - 1) % count -- 0, 1, 2, ...
	-- THE MIDDLE, AND IT IS `floor + 1` SO THE WALK CLOSES ON AN EVEN COUNT TOO (round 3's note).
	-- `ceil` is 5 of 9 and 3 of 6 -- and from 3 the alternating walk over six stands deals
	-- 3, 2, 4, 1, 5, 0: stand 6 is never dealt at all and hunter 6 falls off the line (the clamp
	-- round 3 added bounds him onto stand 1, which is a doubling rather than a hole, but it is still
	-- not the line). From `floor(6/2) + 1` = 4 it deals 4, 3, 5, 2, 6, 1 -- every stand exactly once.
	-- ODD COUNTS ARE UNCHANGED: `floor(9/2) + 1` is 5, which is `ceil(9/2)` and `PICK.defaultIndex`.
	local middle = math.floor(count / 2) + 1 -- 5 of 9, 4 of 6
	local step = math.ceil(zero / 2) -- 0, 1, 1, 2, 2, 3, 3, ...
	local side = if zero % 2 == 1 then -1 else 1 -- 5, 4, 6, 3, 7, ...
	-- CLAMPED INTO THE LINE (round 2, note). The centre-out walk only closes on an ODD count: with
	-- the 6-stand `edge` layout live, index 6 answers stand 0 and index 8 answers -1 -- and
	-- `postIndexFor` then finds no `Stand0`, falls back to the raw index, and `Body.placementFor`'s
	-- modulo lands the hunter on whichever post happens to be last. Unreachable with bots
	-- (`Match.CONFIG.BOTS.TARGET.hunters` is 4), reachable with six real hunters. A clamp is the
	-- honest answer: the outside of the walk is the end of the line, and there is no stand past it.
	return math.clamp(middle + step * side, 1, count)
end

-- `ForestTest.standIndexFor`'s OWN SEQUENCE, AS A LIST (task 221). PURE.
--
-- `{ standIndexFor(1), standIndexFor(2), ... standIndexFor(standCount) }`, which is the centre-out
-- order over every stand of this layout: `5, 4, 6, 3, 7, 2, 8, 1, 9` on the road.
--
-- IT IS DERIVED AND NOT RE-IMPLEMENTED, and that is the point: `HighSeats.dealLine` needs the walk
-- as a list in order to deal the whole line at once, and a second hand-written copy of the
-- centre-out arithmetic would be exactly the two-pieces-of-code-disagreeing failure this project is
-- named after. `forest_stand.spec` already pins the permutation `standIndexFor` produces, so this
-- is pinned with it.
function ForestTest.standWalk(): { number }
	local out: { number } = {}
	for index = 1, chosen.layout.standCount do
		table.insert(out, ForestTest.standIndexFor(index))
	end
	return out
end

-- WHICH OF THIS LAYOUT'S STANDS CARRY A HIGH SEAT, as a SET keyed by stand index (task 221).
--
-- `ReplicatedStorage.HighSeats` is the frozen data and this is the one place the live layout's name
-- is applied to it, so the deal and the thing `Seats.ensure` actually builds read one table. It is
-- NOT a second record of where the seats are: `Seats.ensure` builds from the same `standsFor`.
function ForestTest.seatedStands(): { [number]: boolean }
	local out: { [number]: boolean } = {}
	for _, index in ipairs(Plan.standsFor(chosen.name)) do
		out[index] = true
	end
	return out
end

-- WHICH ENTRY OF `markers.posts` IS STAND `index`. PURE.
--
-- IT EXISTS BECAUSE A STAND CAN BE REFUSED. `Body.placementFor` indexes the list modulo how many
-- posts there ARE, which is right in a world whose posts are all there -- and MEASURED in this one,
-- a run came back `8/9 stands (1 refused), max ground delta 6.99`, because `Data.groundAt`'s ray can
-- stop on a canopy over one stand. With eight posts in the list, `posts[5]` is no longer stand 5,
-- and the drive aims every wave at stand 5's x: the hunter would be standing somewhere the push is
-- not. So the post is found by the NAME `ForestTest.Markers` gave it, and the modulo is the
-- fallback for a world that names them differently (the DEV place, which never calls this).
function ForestTest.postIndexFor(posts, index: number): number
	local wanted = string.format("Stand%d", index)
	for at, post in ipairs(posts or {}) do
		if post.Name == wanted then
			return at
		end
	end
	return index
end

-- THE BOAR RUNTIME AS `Match` MAY SEE IT IN THIS WORLD: two signals and three reads, and NO `spawn`,
-- `spawnSounder` or `clear` (task 157, design section 9.4).
--
-- IT IS HOW THE DRIVE SCORES WITHOUT OWNING THE ANIMALS. `Match` connects `Downed` and `Despawned`,
-- so kills, escapes, assists and a beater's PUSH points all work; and because the view has no
-- `clear`, `Match`'s own `applyClearBoars` -- which is already written as
-- `if world.boars and world.boars.clear` -- does nothing at a drive boundary, so the wood this world
-- stocked is never wiped by the drive. One owner of "when an animal exists", enforced by the shape of
-- the table rather than by a comment.
function ForestTest.readOnlyBoars(runtime)
	return {
		Downed = runtime.Downed,
		Despawned = runtime.Despawned,
		boars = function(_self)
			return runtime:boars()
		end,
		count = function(_self)
			return runtime:count()
		end,
		capacity = function(_self)
			return runtime:capacity()
		end,
		-- THE REAL ANIMALS AT THE GATHERING (task 173), and it belongs in a READ-ONLY view because it
		-- CREATES NO BOAR AND MOVES NONE: it builds a fresh, unparented display model out of this
		-- runtime's own template for that kind, registers nothing with the runtime, holds no slot and
		-- touches no live animal. The drive parents it into its own `Workspace.DriveScene` and
		-- destroys it with that folder.
		--
		-- IT IS NOT "WRITES NOTHING", AND THAT WORD WAS WRONG (round 1, note): a FIRST ask for a kind
		-- fills the runtime's own template cache (`_heldTemplate`, `_askedModelAt`, and the animation
		-- ids). That is the same cache the live draw path fills, for the same kind, from the same
		-- source -- so it changes what this world DRAWS by nothing at all. What the read-only view
		-- exists to refuse is `spawn` and `clear`, and it still refuses both.
		--
		-- So the Forest Test's rule is unchanged -- the drive may not spawn, clear or move an animal
		-- in a world it does not own -- while the row of boxes at the end of a drive becomes the real
		-- animals here too, which is the place Karen plays.
		displayCarcass = function(_self, kind: string?, cframe: CFrame)
			return runtime:displayCarcass(kind, cframe)
		end,
	}
end

-- ---------------------------------------------------------------- where a beater is put down
--
-- THE GROUND, ASKED OF THE TERRAIN ALONE (task 153). `Data.groundAt` excludes `OurForest`,
-- `Foliage` and `Boars` -- and MEASURED in this place today, that is not every tree: 831 more trees
-- and bushes live in two folders both called `Session` (771 and 60 children: "Mesh Tree", "Tree3",
-- "Bush3"), so a downward ray there can stop on a canopy. For a boar that is a spawn a little high;
-- for a character it is a 60-stud fall at the start of the walk Karen is here to feel. An INCLUDE
-- filter of nothing but `Workspace.Terrain` cannot hit a tree at all, which is the honest question:
-- where is the ground.
function ForestTest.terrainYAt(x: number, z: number): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	params.IgnoreWater = true
	local hit = Workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1200, 0), params)
	return if hit then hit.Position.Y else nil
end

-- IS THERE ROOM TO STAND HERE? Anything SOLID within `radius`, excluding the terrain she stands on,
-- the animals and any character, means no.
--
-- `RespectCanCollide` IS THE WHOLE TEST (and it was measured before it was written): this forest is
-- mostly ferns and leaf cards with `CanCollide = false` -- `Workspace.OurForest.SM_Lady_Fern_Var02`
-- is the first part in the folder -- and a beater standing in a fern is standing in a forest. What
-- she may not be standing in is a trunk, and a trunk collides.
--   https://create.roblox.com/docs/reference/engine/classes/WorldRoot#GetPartBoundsInRadius
function ForestTest.roomToStand(point: Vector3, radius: number): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { Workspace.Terrain :: Instance }
	local boars = Workspace:FindFirstChild("Boars")
	if boars then
		table.insert(ignore, boars)
	end
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	params.MaxParts = 8
	for _, part in ipairs(Workspace:GetPartBoundsInRadius(point, radius, params)) do
		-- A PLAYER IS NOT AN OBSTACLE: she may be standing on the road inside this radius already
		-- when the point is computed, and refusing her own body would walk the search sideways for
		-- no reason.
		--
		-- THROUGH `Data.characterOf` SINCE TASK 158, so "what is a person" is ONE rule and not two:
		-- `Data.groundAt` asks the same question of a raycast hit, for the same reason, and the two
		-- used to be able to disagree -- this one read only the hit part's immediate `Parent`, which
		-- calls a hat an obstacle.
		if Data.characterOf(part) == nil then
			return false
		end
	end
	return true
end

-- HOW WIDE AND HOW TALL A PERSON IS, for the one measurement no cast can make (`laneAhead` below).
-- A Roblox character is 2 studs across and about 5 tall, so the half-width is 1.
--
-- THE HEIGHT IS WHAT KEEPS A BODY ABOVE `Bots.CONFIG.JUMP_OVER_STUDS` (4), so a body is always gone
-- ROUND and never jumped over -- and round 1's blocking finding 1 is that the arithmetic below did
-- not deliver that. With a walker's root at the same level as the caster's, `laneAhead` now reports
-- `BODY_HEIGHT_STUDS / 2 + LANE_BODY_SIZE.Y / 2` = 2.5 + 2.5 = **5.0**, which is above 4. A beater
-- hopping over a hunter is a thing Karen would see.
--
-- They are named rather than written into the loop because they are the same two numbers
-- `Bots.CONFIG.LANE_BODY_SIZE` is built from.
ForestTest.BODY_HALF_WIDTH_STUDS = 1
ForestTest.BODY_HEIGHT_STUDS = 5

-- WHAT IS IN THE WAY BETWEEN HERE AND THERE, AND HOW HIGH IT IS (task 208). Returns how far down
-- the path the first solid thing stands and how far its top is above the BOTTOM of the swept body,
-- or `nil, nil` when the way is clear. Read-only.
--
-- IT IS `ForestTest.clearRoute`'S OWN CAST (task 127), with that function's own stated reason: *"a
-- raycast down the centreline would miss a trunk its shoulder hits"*. A swept BOX the size of a
-- walking man is the only shape that can answer "will my body fit between here and there".
--   https://create.roblox.com/docs/reference/engine/classes/WorldRoot#Blockcast
--
-- A BODY IS AN OBSTACLE HERE, AND THAT IS THE WHOLE DIFFERENCE FROM `roomToStand`. That function,
-- `nearestSolid` and `Data.groundAt` all say in so many words that *a person is not an obstacle* --
-- which is right for "may she STAND here" and was MEASURED WRONG for "may he WALK there": on
-- 2026-10-19, two bot beaters in the edge drive spent 34.0 s and 6.0 s pinned against ANCHORED BOT
-- HUNTERS standing on the stands their lanes aim 20 studs past, with the clearance reader answering
-- "clear" the whole time because it had been told to ignore exactly that
-- (`docs/research/2026-10-19-bots-unstuck.md` section 4.2). So this reader excludes the Terrain, the
-- animals and the walker's OWN model, and nothing else: another body is a thing to walk round.
--
-- IT ANSWERS IN TWO PASSES AND THEY AGREE ABOUT PEOPLE. The swept cast finds whatever it finds --
-- MEASURED in round 2, that includes `CanQuery = false` parts when `RespectCanCollide` is on, so it
-- can find a bot rig itself -- and the body pass after it catches the ones it did not. Either way a
-- CHARACTER is reported at `BODY_HEIGHT_STUDS`, never at the height of whichever of its parts was
-- hit, so `Bots.Lane.recoveryFor` can never answer "jump" for a person.
--
-- `stepStuds` IS WHAT DECIDES JUMP AGAINST DETOUR (`Bots.Lane.recoveryFor`), so it is measured off
-- the hit part's own top rather than guessed: a fallen log is stepped over and a trunk is not.
-- Design: docs/design/bots.md (section 9.1)
-- Note:   docs/research/2026-10-19-bots-unstuck.md (sections 2.3, 2.5, 3)
function ForestTest.laneAhead(from: Vector3, to: Vector3, size: Vector3, ignore: Instance?): (number?, number?)
	local span = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = span.Magnitude
	if length < 1e-3 then
		return nil, nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { Workspace.Terrain :: Instance }
	local boars = Workspace:FindFirstChild("Boars")
	if boars then
		table.insert(exclude, boars)
	end
	if ignore ~= nil then
		table.insert(exclude, ignore)
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	-- THE SAME `RespectCanCollide` TEST `roomToStand` MAKES, for its own reason: this forest is
	-- mostly ferns and leaf cards with `CanCollide = false`, and a beater walking through a fern is
	-- walking through a forest. What stops him is a thing that collides.
	params.RespectCanCollide = true
	local direction = span.Unit
	local start = CFrame.lookAt(from, from + direction)
	local hit = Workspace:Blockcast(start, size, direction * length, params)
	local ahead: number? = nil
	local step: number? = nil
	if hit ~= nil then
		local away = hit.Position - from
		ahead = Vector3.new(away.X, 0, away.Z).Magnitude
		local part = hit.Instance
		-- A PERSON IS NOT A LOG, EVEN WHEN THE CAST IS THE THING THAT FOUND HIM. MEASURED
		-- 2026-10-19 (round 2): `Blockcast` with `RespectCanCollide = true` DOES return parts whose
		-- `CanQuery` is false -- which every bot rig part is (`Bots.Rig.prepare`) -- so the cast can
		-- answer about a body before the body pass below ever looks. It answers about the PART: a
		-- `HumanoidRootPart` is 2 studs tall, so its top is 1 stud up and the step height comes out
		-- 3.5, under `Bots.CONFIG.JUMP_OVER_STUDS` (4), and the ladder picks "jump" -- a beater
		-- hopping at a hunter, which is the one answer this reader must never give.
		--
		-- `Data.characterOf` IS THE ONE RULE FOR "WHAT IS A PERSON" in this file
		-- (`roomToStand`, `nearestSolid` and `Data.groundAt` all ask it), so the two branches cannot
		-- disagree: whoever finds the body, a body is reported at a body's height.
		local character = if part ~= nil then Data.characterOf(part) else nil
		if character ~= nil then
			local root = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
			local middle = if root ~= nil and root:IsA("BasePart")
				then (root :: BasePart).Position.Y
				else hit.Position.Y
			step = (middle + ForestTest.BODY_HEIGHT_STUDS / 2) - (from.Y - size.Y / 2)
		else
			local top = if part ~= nil and part:IsA("BasePart")
				then (part :: BasePart).Position.Y + (part :: BasePart).Size.Y / 2
				else hit.Position.Y
			step = top - (from.Y - size.Y / 2)
		end
	end

	-- ...AND THEN THE BODIES, BY DISTANCE, BECAUSE NO CAST CAN SEE THEM. MEASURED 2026-10-19 at the
	-- exact spot of a 169-second pin: the same `Blockcast` this function makes found the planted
	-- spruce trunk 3.8 studs ahead, and at the edge drive's 34-second pin the thing in the way was a
	-- bot HUNTER's body -- which every spatial query in the engine skips, because `Bots.Rig.prepare`
	-- sets `CanQuery = false` on every part of every rig (`SHOOTABLE = false`, and its own header
	-- says why: *a prop that stops a pellet changes what the shot hit*). A cast is therefore blind to
	-- exactly the obstacle the measurement found most of, and the only honest answer is to measure
	-- the bodies themselves.
	--
	-- THE BODIES ARE FEW AND NAMED: the players' characters and `Workspace.DriveBots`' rigs, at most
	-- 16 and 8. A point-to-segment distance each, no cast, no `GetDescendants` -- which is why this
	-- can run at `SEE_HZ` for eight walkers and still cost what section 7 of the note measures.
	--
	-- A BODY IS NEVER JUMPED: its reported step height is its own, which is above
	-- `Bots.CONFIG.JUMP_OVER_STUDS`, so `Lane.recoveryFor` always goes ROUND a person. That is the
	-- intent and not an accident -- a beater hopping over a hunter is a thing Karen would see.
	local bodies: { Model } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character ~= nil then
			table.insert(bodies, character)
		end
	end
	local rigs = Workspace:FindFirstChild("DriveBots")
	if rigs ~= nil then
		for _, rig in ipairs(rigs:GetChildren()) do
			if rig:IsA("Model") then
				table.insert(bodies, rig)
			end
		end
	end
	local half = math.max(size.X, size.Z) / 2
	for _, body in ipairs(bodies) do
		if body ~= ignore then
			local root = body.PrimaryPart or body:FindFirstChild("HumanoidRootPart")
			if root ~= nil and root:IsA("BasePart") then
				local at = (root :: BasePart).Position
				-- HOW FAR DOWN THE PATH IT STANDS, and how far off it: the projection onto the
				-- segment, clamped to it, which is the one piece of arithmetic a swept box does for
				-- the parts it can see.
				local along = math.clamp(Vector3.new(at.X - from.X, 0, at.Z - from.Z):Dot(direction), 0, length)
				local nearest = from + direction * along
				local off = Vector3.new(at.X - nearest.X, 0, at.Z - nearest.Z).Magnitude
				if off <= half + ForestTest.BODY_HALF_WIDTH_STUDS and math.abs(at.Y - from.Y) < size.Y then
					if ahead == nil or along < (ahead :: number) then
						ahead = along
						-- ITS TOP AGAINST THE BOTTOM OF THE SWEPT BODY, which is the SAME arithmetic
						-- the cast branch above does -- and round 1's blocking finding 1 is why it is
						-- written that way rather than off the root part's own size. A root part is
						-- 2 studs tall, so `Size.Y / 2 + BODY_HEIGHT_STUDS / 2` came to **3.5**,
						-- BELOW `Bots.CONFIG.JUMP_OVER_STUDS` (4) -- so a bot JUMPED at a person
						-- instead of walking round one, which is the opposite of what this header
						-- and the ladder both say. A man's head is `BODY_HEIGHT_STUDS / 2` above his
						-- root and the swept body's floor is `size.Y / 2` below the caster's.
						local top = at.Y + ForestTest.BODY_HEIGHT_STUDS / 2
						step = top - (from.Y - size.Y / 2)
					end
				end
			end
		end
	end
	return ahead, step
end

-- WHERE A BEATER IS PUT DOWN: behind the line's own spawn, on the ground, clear of trunks (task 153).
--
-- THE PUSH LINE IS THE HUNTER'S STAND, which is the same x the drive releases its lines at
-- (`releaseLine` crosses at `hunterStandX() + crossOffsets[...]`). So a beater standing behind that
-- point is behind the animals and pushing toward the place they cross -- one geometry, not two.
--
-- ...AND `index` IS WHICH LANE OF THE LINE IT IS (task 167). Karen, 2026-10-12: *"and seem like all
-- bots came to me"*. Every beater used to be put on the push line itself, so the whole bot line
-- arrived at the one stand she was standing on. `Data.beaterLaneOffset` deals the indices out across
-- the hunters' front (0, +-150, +-300 ...) and this measures the ground and the trunks at the lane's
-- OWN x -- so the search is still "the nearest clear spot to where this body belongs", which is now
-- a different place for each of them. `nil` is index 1, the push line, which is what every caller
-- before this task meant.
function ForestTest.beaterStartPosition(index: number?): Vector3
	local beater = Data.BEATER
	local standX = ForestTest.hunterStandX() + Data.beaterLaneOffset(index, chosen.layout)
	-- 0, +10, -10, +20, -20 ... : straight behind the crossing first, then the nearest clear spot
	-- either side of it.
	for try = 0, beater.sideTries do
		local side = math.ceil(try / 2) * beater.sideStepStuds * (if try % 2 == 1 then 1 else -1)
		local flat = Data.beaterStart(standX, side, chosen.layout)
		local ground = ForestTest.terrainYAt(flat.X, flat.Z)
		if ground ~= nil then
			local point = Vector3.new(flat.X, ground + beater.dropStuds, flat.Z)
			if ForestTest.roomToStand(point, beater.clearStuds) then
				return point
			end
		end
	end
	-- NOTHING CLEAR WAS FOUND, SO SHE GOES BEHIND THE CROSSING ANYWAY, on the ground. A playtest
	-- that refuses to start is a playtest nobody runs (`Data.PICK.defaultIndex` is the same
	-- reasoning); a beater beside a trunk can walk two steps and be free of it.
	local flat = Data.beaterStart(standX, 0, chosen.layout)
	local ground = ForestTest.terrainYAt(flat.X, flat.Z) or chosen.layout.centre.Y
	return Vector3.new(flat.X, ground + beater.dropStuds, flat.Z)
end

-- THE ARITHMETIC IS REACHABLE ON ITS OWN, so `tests/server/forest_line.spec.luau` can drive the
-- rules a line stands on with hand-written tables instead of a running world.
ForestTest.Line = Line

-- THE DRIVE'S GEOMETRY IN THIS WORLD (task 157), the same shape `Line` has: a child module, exported
-- here, reachable by a spec on its own. `ForestTest.Markers.build` is what `ForestTestBoot` hands to
-- `Match` through `world.markers`.
--
-- ITS TWO GROUND READERS ARE HANDED OVER HERE rather than required there, because a child requiring
-- its parent is a cycle -- and a third copy of the two rays would be two definitions of "where is
-- the ground", which is this project's named failure mode. One home, passed once.
Markers.setReaders(ForestTest.terrainYAt, Data.groundAt)

-- THE HIGH SEATS (task 218), composed here for exactly the same two reasons: `Seats` is a child of
-- this module and cannot require it, and its ground readings must be THE SAME TWO FUNCTIONS -- a
-- seat that stood on a third opinion of the ground would be a seat the stand under it disagreed
-- with. `Markers` then asks the seat where its deck is instead of reading that column itself
-- (design section 7.2), which is why this line comes before `ForestTest.Markers` is exported.
Seats.setReaders(ForestTest.terrainYAt, Data.groundAt)
Markers.setSeatSource(Seats.deckTopY)
ForestTest.Seats = Seats
ForestTest.Markers = Markers

return ForestTest
