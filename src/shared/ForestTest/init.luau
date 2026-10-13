--!strict
-- ForestTest: THE DATA FOR THE PLAYTEST WORLD "Driven Hunt Forest Test", and nothing else.
--
-- It writes no Instance, spawns no boar and arms no gun. Server and client both read it, which is
-- why it is in ReplicatedStorage: the client's stand picker has to know where the road is, and a
-- second copy of a curve is two curves that disagree.
--
-- KAREN, 2026-10-04 ~22:40, on what she wants to test in the morning:
--   *"one side hunters respawn and on another side driver people walk is let's say 1 minute max"*
--   *"hunter line just a hunter no treestand anything"*
--   *"hunter has square where can select stand within 10s and save then he can move few steps"*
--   *"each 20s cross 1 flock then 1 big male then on other side few so to be action"*
--   *"several animals cross road / several go back"*
--   *"I want tomorrow to test shooting and walking"*
--
-- THIS IS A PLAYTEST WORLD, NOT THE GAME'S MAP. The real map is `Map` + `MapGen` and still builds
-- in the DEV place. This describes a hand-built place the Director made from a bought terrain, and
-- its whole job is to let one person stand on a road and shoot things that cross it.
local Workspace = game:GetService("Workspace")

local ForestTest = {}

-- THE PLACE. Everything below is only ever read when `Map.EXPECTED_WORLD` resolves to
-- `ForestTest.WORLD`, which happens only in this place id -- see `Map.WORLD_BY_PLACE`.
ForestTest.PLACE_ID = 130094961655666
ForestTest.WORLD = "forest-test"

-- THE CENTRE the Director built around, and the curve of the road through it.
ForestTest.CENTRE = Vector3.new(3030, 138, -2097)
ForestTest.HALF_SPAN = 800 -- the road runs CENTRE.X +- this

-- THE ROAD IS A SINE, NOT A LINE. Karen: *"hunter position one long road not straight as we have
-- now"*. Amplitude 30 studs over a 440-stud wavelength is a road that bends enough that a shooter
-- cannot see his neighbour down the whole length -- which is the point of it -- without ever
-- doubling back on itself.
ForestTest.ROAD = {
	amplitudeStuds = 30,
	wavelengthDivisor = 70, -- z = C.Z + amplitude * sin((x - C.X) / this)
	halfWidthStuds = 20, -- the cut lane is about 40 studs across
}

-- WHERE THE ROAD IS AT A GIVEN x. The one definition; every other reader calls this.
function ForestTest.roadZ(x: number): number
	return ForestTest.CENTRE.Z
		+ ForestTest.ROAD.amplitudeStuds * math.sin((x - ForestTest.CENTRE.X) / ForestTest.ROAD.wavelengthDivisor)
end

-- THE HUNTER LINE. Karen: *"hunter line just a hunter no treestand anything"* -- so a stand here is
-- a SPOT, not a structure. These are the x values a hunter may choose between; the z comes from the
-- curve, so every one of them is on the road.
--
-- 9 SPOTS OVER 1,200 STUDS is 150 studs apart, which is a real driven-hunt spacing: far enough that
-- two hunters never share a target, close enough that a boar crossing anywhere is somebody's shot.
ForestTest.STAND_COUNT = 9
ForestTest.STAND_SPACING = 150

function ForestTest.standX(index: number): number
	local middle = (ForestTest.STAND_COUNT + 1) / 2
	return ForestTest.CENTRE.X + (index - middle) * ForestTest.STAND_SPACING
end

-- WHERE A HUNTER STANDS, as a world position on the road.
function ForestTest.standPosition(index: number): Vector3
	local x = ForestTest.standX(index)
	return Vector3.new(x, ForestTest.CENTRE.Y, ForestTest.roadZ(x))
end

-- THE PICK. Karen: *"hunter has square where can select stand within 10s and save then he can move
-- few steps on each side max"*.
ForestTest.PICK = {
	seconds = 10,
	-- HOW FAR HE MAY THEN MOVE, AND IT IS NOW A BOUNDARY RATHER THAN A LEASH (task 166).
	--
	-- KAREN, 2026-10-12 ~16:00, having played it: *"yes inaught but it always put me at the same
	-- place even I moved a bit we need boundries but not put back where it started"*.
	--
	-- WHAT WAS PUTTING HER BACK WAS MEASURED, not guessed, because three things could have done it
	-- (the Forest Test's own hold, `Match.Body.settle`'s drift re-pivot, or the stand placement
	-- re-pivoting). In a Play session of the Forest Test on 2026-10-12, with stand 5 locked, the
	-- character was moved 20 studs north of its stand and its distance from the stand sampled every
	-- Heartbeat for four seconds:
	--     0.0s 20.00   0.1s 6.00   0.2s 6.00   ... 4.0s 6.00
	-- ONE Heartbeat, 20 studs -> 6.000, and 6.000 for every sample after it. So it is this number
	-- and the hold that reads it, and nothing else: `Body.settle` fires once per placement and
	-- would have landed her at 0.00, and no re-pivot ran at all.
	--
	-- 6 STUDS WAS 1.7 METRES. At `Report.CONFIG`'s 0.28 m per stud a hunter could stand up and shift
	-- his feet and nothing more, and every step past it was written back to exactly 6.000 -- at 16
	-- studs a second that is a correction every frame, which is the rubber band she felt and
	-- described as being put back where she started.
	--
	-- 12 IS THE DIRECTOR'S START VALUE AND IT IS 3.4 METRES: a stand's own platform is 6 studs
	-- across (`Markers.POST_SIZE`), so 12 studs of radius is a circle four platform-widths wide --
	-- room to walk off the post, turn, and take a step to either side for a shot, which is what a
	-- hunter on a stand actually does. It is one line, and Karen's to change.
	standRadiusStuds = 12,
	-- If he picks nothing, he gets one anyway. A playtest that begins by refusing to start is a
	-- playtest nobody runs.
	defaultIndex = 5,
}

-- THE DRIVERS. Karen: *"driver people walk is let's say 1 minute max"*.
--
-- 700 STUDS, AND THE ARITHMETIC IS WORTH WRITING DOWN. A Roblox Humanoid walks 16 studs a second,
-- so 700 studs is 44 seconds on open ground. This line is through standing forest with trunks to go
-- round, which is what makes it about a minute in practice. It is NORTH of the road because the
-- boar's escape axis is baked southward (`Boar.CONFIG.field.exitZ`), and the Director's instruction
-- was not to change that axis.
-- WHICH WAY THE DRIVE COMES FROM, as a compass bearing (task 125). Karen, 2026-10-05: *"we need to
-- indicate from what side drive is comming"* and *"compass and showing where drive come direction"*.
--
-- DERIVED, NOT CHOSEN. `DRIVERS.startNorthStuds` is 700 and `driverStart` puts them at
-- `roadZ(x) + that` -- so the beaters begin 700 studs NORTH of the road and push south onto it.
-- North is +Z and is bearing 0, so the drive comes from 0. It is written down as its own value
-- because the HUD must not re-derive a fact from a position: the drive's direction is this world's
-- to state and the compass's to draw.
ForestTest.DRIVE_BEARING_DEG = 0

ForestTest.DRIVERS = {
	startNorthStuds = 700,
	walkSpeed = 16,
}

function ForestTest.driverStart(index: number, count: number): Vector3
	local spread = ForestTest.HALF_SPAN * 1.2
	local t = if count <= 1 then 0.5 else (index - 1) / (count - 1)
	local x = ForestTest.CENTRE.X - spread / 2 + spread * t
	return Vector3.new(x, ForestTest.CENTRE.Y, ForestTest.roadZ(x) + ForestTest.DRIVERS.startNorthStuds)
end

-- ---------------------------------------------------------------- starting AS a beater (task 153)
--
-- KAREN, 2026-10-11: *"how to start a game as a beter?"*, and then the decision --
--   *"you start as a hunter then next round you are beater ... and yes beater are behind animals and
--   moving towards hunter line (road) like in real life ... I think we need to focus now to be a
--   beater / we will try walk spook, use horn have that feeling and improve"*.
--
-- SO A BEATER STARTS BEHIND THE ANIMALS, ON THE DRIVE SIDE, FACING THE ROAD. The rotation between
-- the two roles is the NEXT task; this is the geometry of the experience.
--
-- IT IS MEASURED FROM THE LINE'S OWN START. `LINE.spawnNorthStuds` (180) is where this world
-- releases a line of boars; a beater `behindLineStuds` further north is therefore behind every
-- animal the drive has just put on the ground. `DRIVERS.startNorthStuds` (700) is the OTHER
-- drive-side point this world owns, and it is not this one.
--
-- 60 -> 400, AND THE REASON CHANGED WITH IT (task 162). KAREN, 2026-10-12: *"can we make drive
-- longer, it's to fast / good for testing but now need longer walk for beaters let's say 2 min"*.
-- Until today this number only had to CLEAR the line's animals, and 60 studs did; now it has to
-- make a two-minute walk at the bot pace, so it is chosen by the walk and being behind the line is
-- a CHECKED CONSEQUENCE (`forest_stand.spec`) rather than the reason.
--
--   (spawnNorthStuds 180 + behindLineStuds 400 + Match.CONFIG.BOTS.GOAL_PAST_LINE_STUDS 20)
--     / Bots.CONFIG.WALK_SPEED 5  =  120.0 s
--
-- A BOT LINE IS WHAT ENDS A DRIVE HERE (`Match.beaterCrossing` counts bots into the line), so that
-- product IS the length of a drive, and `bots_lane.spec` asserts it against `DRIVE.seconds` (300).
--
-- 580 IS WHAT THE WOOD HOLDS, MEASURED in this place on 2026-10-12 (`test`'s own Edit session, nine
-- stand columns from x 2430 to 3630, sampled every 25 studs out to 1,000):
--   * TERRAIN carries on past 1,000 studs north at every one of the nine, with no gap;
--   * TREES -- a colliding part within 25 studs -- run out at 775-850 studs depending on x, and
--     past that it is bare hillside. So the WOOD is about 775 studs deep and a start at 580 is
--     inside it with room to spare;
--   * the ground rises from y 140 at the road to y 234 at 575 studs north and falls away beyond
--     600, so 580 puts the line ON the crest, looking down the hill at the road;
--   * the ground path from the pad at the middle stand down to the road is 611.6 studs against 580
--     flat, so the real walk is ~126 s rather than 120 -- longer, never shorter;
--   * the pad column itself (x 3030): terrain 234.1, `groundAt` 234.1 (delta 0.00, so
--     `Markers.groundFor` builds `BeaterStart` and the drive starts), `roomToStand` true at
--     `clearStuds`, nearest trunk 12.4 studs -- in the trees, not inside one.
-- 700 WOULD ALSO FIT THE WOOD. It is not taken because the pair has to make 120 s and 580 is the
-- half of it that leaves the pace realistic (`Bots.CONFIG.WALK_SPEED`, 1.40 m/s).
ForestTest.BEATER = {
	behindLineStuds = 400,
	-- HOW CLOSE A TRUNK MAY BE to where she is put down. A Roblox character is 2 studs across, so 6
	-- is a body's width of clearance on every side: enough that she does not land inside a tree.
	clearStuds = 6,
	-- ...and how a clear spot is looked for when the straight-behind point is blocked: sideways,
	-- alternating east and west, so the first answer is always the nearest one to the push line.
	sideStepStuds = 10,
	sideTries = 8,
	-- HOW FAR APART THE LANES OF THE LINE ARE, AND IT IS ONE STAND (task 167).
	--
	-- KAREN, 2026-10-12 ~16:10, having played a drive as a hunter with the bots on: *"and seem like
	-- all bots came to me"*. She was right, and the geometry says why: every beater -- real or bot --
	-- was put down at ONE measured point, the push line through the stand she had locked, and the
	-- bot lanes were +-18 and +-36 studs about it. Four bodies inside 72 studs of her stand is not a
	-- drive line, it is a queue at her feet.
	--
	-- A LINE SPANS THE FRONT. `index` is the beater's place in it (the drive asks `placement` for
	-- index 1, 2, 3 ... exactly as it asks for a hunter's stand), and `beaterLaneOffset` deals those
	-- indices out across the hunters' line: 0, +150, -150, +300, -300 ... So four bot beaters cover
	-- 600 studs of front -- stands 3 to 7 with her in the middle of them -- and each walks its own
	-- lane down to its own stretch of road.
	--
	-- 150 IS `STAND_SPACING`, AND THAT IS THE WHOLE REASON FOR THE NUMBER. A lane laid out on the
	-- stand grid lands square in front of a stand, so `Match.beaterGoalFor` (which takes the post
	-- NEAREST the lane's own start) and `Match.crossedLine` (which takes the same one) pick that same
	-- post -- the goal is straight ahead of the lane and arriving at it IS crossing. Any other
	-- spacing puts the goal in front of a stand the lane is not walking at, on a road that is a sine
	-- 30 studs deep. It is also a real beater interval: 150 studs is 42 m at
	-- `ForestTest.SPOOK.METRES_PER_STUD`.
	laneSpacingStuds = ForestTest.STAND_SPACING,
	-- How far above the ground she is put, so she drops onto it rather than into it. It used to be
	-- *"the same 4 studs `ForestTest.spawnPosition` uses for a hunter"*, and task 157 archived that
	-- function: a hunter is now put down by the drive, on the marker part `ForestTest.Markers` builds
	-- at the ground `terrainYAt` measured, plus `Match.CONFIG.STAND_HEIGHT_STUDS`.
	dropStuds = 4,
}

-- HOW CLOSE SHE MAY GET BEFORE THEY GO, AND WHAT GOING MEANS (task 154).
--
-- KAREN, 2026-10-11, after the first beater playtest: *"so animals already there somewhere in
-- bushes close to trees ect / once I get a bit closer they just run away without stop it's not like
-- they cool down they spooked and run away / so from me direction they looking they run away / horn
-- reach is further once they hear also run without stop"*.
--
-- TWO NUMBERS AND ONE RULE. The numbers are the two reaches -- how close she has to walk, and how
-- far the horn carries -- and the rule is the SAME ONE for both, and the same one task 150 built
-- for a heard shot: the fright latches, the animal keeps the line it set off on, it never settles,
-- and the only thing that ends it is leaving at `EXIT_Z`. There is no second panic system, because
-- two systems that both decide when an animal calms down is this project's named killer (rule 3).
--
-- IN METRES *AND* IN STUDS, which is task 150's lesson and `Horn.CONFIG`'s shape: a radius written
-- in studs was compared against distances in metres for two tasks. Both spellings are here so a
-- world or a spec may override either unit, and `forest_stand.spec` asserts they agree to the stud.
--
-- 25 m IS THE DIRECTOR'S START VALUE, and it is a real number for this animal rather than a round
-- one: the flight-initiation distance of wild boar to a person on foot is tens of metres, not the
-- 25 STUDS (7 m) this world used before today -- `PACE.DRIVER_RUN_STUDS`, which is "a driver this
-- close makes it run" and was the whole of the beater's reach in task 153. At 7 m she was on top of
-- them before anything moved, which is not what walking a wood is like.
--
-- ...AND SINCE TASK 172 THERE ARE TWO REACHES AND A CLOCK, because one reach is a disappearance.
-- KAREN, 2026-10-13 ~09:20, after playing 168-171: *"beaters has to see more animals when walking I
-- want to see how they stand and then start to run or run but I want to see them more"*.
--
-- WHAT SHE WAS LOOKING AT, AND IT IS ARITHMETIC RATHER THAN TASTE: the one reach was 25 m and the
-- fright LATCHED, so the first thing a walking beater ever did to a group was make it bolt -- at 25 m,
-- through a wood whose trunks close the view long before that. By the time she could see where the
-- noise came from, the animals were running away at `PACE.RUN_SPEED`. She never saw an animal; she
-- saw a wood with something leaving it.
--
-- SO THE ENCOUNTER HAS THREE STAGES NOW, and every one of them is a number in this table:
--   NOTICE   35 m -- the group STOPS, puts its head up and faces him (`Brain:notice`, which is task
--            118's own ALERT state asked for from outside). Nothing runs; nothing latches.
--   ALERT    2 s  -- how long that look holds before the group breaks. The Director's start value,
--            inside the dispatch's "~1-2 s".
--   FLUSH    20 m -- ...or closer than this, whichever comes first, and THEN they bolt and never
--            stop, which is task 154's latch unchanged.
-- `ForestTest.encounterStage` is the whole machine, pure, and `forest_stand.spec` asserts each stage.
ForestTest.SPOOK = {
	METRES_PER_STUD = 0.28, -- the same number `Horn.CONFIG`, `Report.CONFIG` and `Boar.CONFIG.SENSE` publish
	-- HOW FAR OFF A GROUP NOTICES HIM. 35 m is the Director's start value and it is a real number for
	-- this animal as well: the flight-initiation distance of wild boar to a person on foot is tens of
	-- metres, and the whole band between noticing and fleeing is what a stalker calls the stand.
	NOTICE_M = 35,
	NOTICE_STUDS = 125, -- 35 m / 0.28
	-- HOW LONG THEY STARE BEFORE THEY GO. It is the WORLD's number and not the animal's -- the Brain
	-- has `SENSE.ALERT_SECONDS` (2.5) for a hunter who happens to be standing about, and a drive is a
	-- man walking at them, so the drive says how long its own stage lasts and hands it in.
	ALERT_SECONDS = 2,
	-- ...AND HOW CLOSE HE MAY GET BEFORE THEY GO WHATEVER THE CLOCK SAYS. 20 m, down from 25: the
	-- stage above is what she asked to see, so the bolt belongs at the near edge of it.
	BEATER_M = 20,
	BEATER_STUDS = 71, -- 20 m / 0.28

	-- THE LINE SWEEPS WHAT IT PASSES (task 168, the Director's second pass). KAREN, 2026-10-12
	-- ~21:50: *"animals can't come behind beaters"*, and ~21:55: *"once beater push they go or turn
	-- around but not after beaters ahead and they come from backs"*.
	--
	-- WHAT THE CIRCLE LEFT BEHIND, MEASURED: a live drive left **13 of 27 animals behind the line
	-- without their ever having moved**. `BEATER_STUDS` is a RADIUS round each body, so the depth it
	-- covers TAPERS to nothing sideways -- midway between two lanes 150 studs apart it is
	-- `sqrt(89^2 - 75^2)` = 47.9 studs, and the two lanes' circles leave the ground between them
	-- thinly covered rather than swept. The animals Karen watched come out behind the beaters were
	-- never pushed at all: the line walked past them.
	--
	-- SO THE FRONT IS A LINE AND NOT A ROW OF CIRCLES. `ForestTest.lineFrontAt` interpolates the
	-- beaters' own z ACROSS the front, so every x on it has a front -- there is no gap between two
	-- lanes to derive, because there is no gap. What IS derived from the lane spacing is the DEPTH,
	-- below.
	SWEEP = {
		ENABLED = true,
		-- A FLOOR under the derived depth, so a world that put its lanes `2 * BEATER_STUDS` apart
		-- (where the formula answers 0) still sweeps something. 30 studs is 8.4 m -- about three
		-- strides of a walking man, which is one tick of the line at any pace it will ever walk.
		MIN_AHEAD_STUDS = 30,
		-- ...AND EVERYTHING BEHIND THE FRONT IS SWEPT, WITH NO LIMIT, which is the whole rule: an
		-- animal the line has passed is exactly the animal Karen is complaining about. It is written
		-- as a number rather than as `math.huge` so a spec can state it, and it is this world's own
		-- depth: nothing is ever further behind the line than the walk itself.
		BEHIND_STUDS = 1200,
	},
}

-- HOW DEEP THE SWEEP REACHES IN FRONT OF THE LINE, derived from the lane spacing (task 168).
-- PURE, and the derivation is the whole point: it is the depth the OLD per-beater circle really had
-- at the worst place on the front -- midway between two lanes -- promoted to the whole front.
--
--     sqrt(BEATER_STUDS^2 - (laneSpacing / 2)^2)
--
-- So the band is NO WEAKER than the circles anywhere (it is exactly their worst case) and strictly
-- stronger between two lanes, where the circle tapered. With the shipped numbers -- reach 89, lanes
-- 150 -- it is **47.9 studs**, and the line covers that in ten seconds of its own walk.
--
-- THE FLOOR IS `MIN_AHEAD_STUDS`, for a lane spacing at or past `2 * BEATER_STUDS`, where the
-- formula answers zero or is imaginary: a line of men that far apart is not a line, and the honest
-- answer is "a man's own few strides" rather than an error.
local function bandDepth(reach: number, beater, spook): number
	local half = ((beater or ForestTest.BEATER).laneSpacingStuds or 0) / 2
	local floor = ((spook or ForestTest.SPOOK).SWEEP or {}).MIN_AHEAD_STUDS or 0
	local inside = reach * reach - half * half
	if inside <= 0 then
		return floor
	end
	return math.max(floor, math.sqrt(inside))
end

function ForestTest.sweepAheadStuds(spook, beater): number
	return bandDepth(ForestTest.beaterSpookStuds(spook), beater, spook)
end

-- ...AND THE SAME DERIVATION FOR THE NOTICE BAND (task 172), because it is the same geometry asked
-- of the bigger reach: midway between two lanes a circle of radius `NOTICE_STUDS` reaches
-- `sqrt(125^2 - 75^2)` = 100 studs in front of the front, and that is the depth promoted to the
-- whole of it. With the shipped numbers the two bands are 100 studs (notice) and 30 studs (flush,
-- the floor -- a flush circle of 71 studs does not reach halfway across a 150-stud lane gap at all),
-- so a group is looked at a long way before anything decides to run. That ORDER is not an accident
-- and `forest_stand.spec` asserts it: a notice band narrower than the flush band would mean animals
-- that bolt without ever having been seen to stand, which is the whole defect this task fixes.
function ForestTest.noticeAheadStuds(spook, beater): number
	return bandDepth(ForestTest.noticeStuds(spook), beater, spook)
end

-- WHERE THE LINE'S FRONT IS AT THIS x. PURE: a list of beater positions in, the z of the line at
-- `x` out, or nil when nobody is pushing.
--
-- LINEAR INTERPOLATION BETWEEN THE TWO NEAREST LANES, and CLAMPED to the outermost beater past
-- either end -- which is what makes the front continuous and the coverage gapless by construction
-- rather than by a number somebody tuned. A front of one man is that man's own z everywhere, which
-- is right: a solo beater IS the line.
--
-- THE SORT IS DONE HERE AND NOT ASSUMED, because the caller's list is built from
-- `Players:GetPlayers()` plus the bot rigs in creation order, and neither is sorted by x.
function ForestTest.lineFrontAt(beaters, x: number): number?
	local points = {}
	for _, beater in ipairs(beaters or {}) do
		if typeof(beater.position) == "Vector3" then
			table.insert(points, beater.position)
		end
	end
	if #points == 0 then
		return nil
	end
	table.sort(points, function(a, b)
		return a.X < b.X
	end)
	if x <= points[1].X then
		return points[1].Z
	end
	local last = points[#points]
	if x >= last.X then
		return last.Z
	end
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		if x >= a.X and x <= b.X then
			local span = b.X - a.X
			if math.abs(span) < 1e-9 then
				return a.Z
			end
			return a.Z + (b.Z - a.Z) * ((x - a.X) / span)
		end
	end
	return last.Z
end

-- IS THIS ANIMAL INSIDE THE SWEEP? PURE, in the two numbers that matter: how far IN FRONT of the
-- front it is (`aheadStuds`, positive toward the road, negative for an animal the line has passed)
-- and how deep the band reaches.
--
-- EVERYTHING BEHIND THE FRONT IS CAUGHT, which is the rule Karen asked for -- *"not after beaters
-- ahead"*. An animal can therefore be behind the line for one tick of the push and no longer: the
-- band moves with the front, so the moment the front reaches it, it goes.
function ForestTest.sweepCatches(aheadStuds: number, depthStuds: number, spook): boolean
	local sweep = (spook or ForestTest.SPOOK).SWEEP
	if sweep == nil or sweep.ENABLED ~= true then
		return false
	end
	if aheadStuds > depthStuds then
		return false -- still comfortably in front of the line: its turn has not come
	end
	return aheadStuds >= -(sweep.BEHIND_STUDS or 0)
end

-- WHAT THIS ANIMAL'S ENCOUNTER WITH THE LINE HAS REACHED (task 172). PURE, in the four numbers that
-- decide it, and it is the WHOLE state machine -- `ForestTest.spookNearBeaters` does nothing but
-- take the measurements and obey the answer.
--
--   `aheadStuds`   how far IN FRONT of the line's interpolated front it is (`lineFrontAt`), negative
--                  for an animal the line has passed. The 168 band, which is gapless across x.
--   `gapStuds`     how far the NEAREST beater's body is, flat. The 154 circle.
--   `alertedFor`   how long it has been holding a look, or nil for an animal that has not noticed.
--
-- THREE ANSWERS: "none", "notice" (stand and look) and "flush" (bolt, and never stop).
--
-- THE BAND AND THE CIRCLE ARE A UNION, AND THAT IS DELIBERATE. Task 154 used the circle alone and
-- its coverage TAPERED sideways, so a group midway between two lanes was never touched (168 measured
-- 13 animals of 27 standing where they were while the line walked past them). Task 168 replaced it
-- with the band, which is gapless but shallow. Either one alone is weaker than both: the band is
-- what makes "nothing is left behind the line" true at any x, and the circle is what makes a beater
-- walking straight at a group matter at his own reach rather than at the band's depth. They are both
-- "how close is too close", asked of one geometry, and the nearer trigger wins.
--
-- ...AND THE CLOCK IS WHAT ENDS THE STAND. A group that has looked for `ALERT_SECONDS` breaks
-- whether or not he has closed any further, which is what a real group does and what stops an
-- approach that stalls from freezing a herd in a stare for ever.
function ForestTest.encounterStage(aheadStuds: number, gapStuds: number, alertedFor: number?, spook, beater): string
	local resolved = spook or ForestTest.SPOOK
	local flush = ForestTest.beaterSpookStuds(resolved)
	if
		ForestTest.sweepCatches(aheadStuds, ForestTest.sweepAheadStuds(resolved, beater), resolved)
		or gapStuds <= flush
		or (alertedFor ~= nil and alertedFor >= ForestTest.alertSeconds(resolved))
	then
		return "flush"
	end
	if
		ForestTest.sweepCatches(aheadStuds, ForestTest.noticeAheadStuds(resolved, beater), resolved)
		or gapStuds <= ForestTest.noticeStuds(resolved)
	then
		return "notice"
	end
	return "none"
end

-- THE REACH IN STUDS, from whichever unit the table carries. PURE, and the ONE place the conversion
-- happens -- `Horn.spookStuds`'s rule, for the same reason: no caller multiplies by
-- `METRES_PER_STUD` itself. The studs win when they are there, because a world that overrides the
-- studs means the studs.
-- HOW FAR OFF A GROUP NOTICES A BEATER, in studs, from whichever unit the table carries (task 172).
-- `beaterSpookStuds`'s own rule, one reach up: the studs win when they are there.
function ForestTest.noticeStuds(spook): number
	local resolved = spook or ForestTest.SPOOK
	if type(resolved.NOTICE_STUDS) == "number" then
		return resolved.NOTICE_STUDS
	end
	if type(resolved.NOTICE_M) == "number" then
		return resolved.NOTICE_M / resolved.METRES_PER_STUD
	end
	-- A WORLD THAT NAMES NO NOTICE REACH gets the flush reach, which is the game before this task:
	-- noticing and fleeing at one distance is exactly what 154 built.
	return ForestTest.beaterSpookStuds(resolved)
end

-- HOW LONG A NOTICED GROUP HOLDS ITS LOOK, in seconds, with a world's override honoured the same way.
function ForestTest.alertSeconds(spook): number
	local resolved = spook or ForestTest.SPOOK
	if type(resolved.ALERT_SECONDS) == "number" then
		return resolved.ALERT_SECONDS
	end
	return 0
end

function ForestTest.beaterSpookStuds(spook): number
	local resolved = spook or ForestTest.SPOOK
	if type(resolved.BEATER_STUDS) == "number" then
		return resolved.BEATER_STUDS
	end
	return resolved.BEATER_M / resolved.METRES_PER_STUD
end

-- WHICH WAY A BEATER IS PUSHING, as a compass bearing. `DRIVE_BEARING_DEG` is where the drive comes
-- FROM (0, north) and that is what a hunter's compass marks; a beater walks the other way, so her
-- marker is the road. Derived from the one fact above it, never written twice.
ForestTest.PUSH_BEARING_DEG = (ForestTest.DRIVE_BEARING_DEG + 180) % 360

-- ...AND THE WORD THAT GOES WITH IT (task 153 round 2, the Reviewer's blocking finding). The marker
-- is a chevron and a label, and turning the chevron round without the label gave a beater a compass
-- saying the DRIVE is south while every animal she is pushing is north of her. The hunter's word is
-- the Hud's own `Compass.CONFIG.DRIVE_LABEL`; this is the beater's, and it lives beside the bearing
-- it belongs to so the two can never be changed apart.
ForestTest.PUSH_LABEL = "ROAD"

-- WHICH TEAM IS DOING THE PUSHING, so the HUD never hard-codes a team name. The string itself is
-- `Drive.TeamName`'s and the one translator from Karen's word to it is `Match.Body.ROLE_WORDS`;
-- this is the world saying which of the two is the beater's, for a client that can only see
-- `Player.Team`.
ForestTest.PUSH_TEAM = "Drivers"

-- THE START SWITCH (task 153). An attribute on `ServerStorage`, set in Edit mode, that says which
-- role a player STARTS as in this place -- so Karen can press Play and already be a beater instead
-- of typing `/beater` on the road. Default (no attribute) is the hunter this world has always
-- started her as.
--
-- AN ATTRIBUTE AND NOT A FILE, for the same reason `tools/flags.py` uses one: it is a playtest
-- setting, it must not show up in the git tree, and it survives into the Play session because Play
-- copies the Edit DataModel. It is NOT a `DHFlag_*` name, so the harness's override guard -- which
-- refuses to run while a flag override is set -- cannot see it and cannot be defeated by it.
ForestTest.START_ROLE_ATTRIBUTE = "DHForestStartRole"

-- WHICH LANE OF THE LINE THIS BEATER WALKS, as an offset along the road from the push line (task
-- 167). PURE, and the one answer to *"all bots came to me"*.
--
-- INDEX 1 IS THE PUSH LINE ITSELF and gets 0, so a REAL beater -- she is always index 1, because the
-- drive numbers its own players first -- starts exactly where task 153 put her and nothing about
-- Karen's own walk changes. The bots take 2, 3, 4, 5 and therefore +-1 and +-2 stand spacings, so
-- when she walks as a beater the middle of the line is hers and the bots flank her. That is the
-- property `Bots.Lane`'s archived `offsetFor` was written for (*"lane 0 is never issued, so the
-- middle stays the PEOPLE's"*), kept, and moved to the world that knows how wide a front is.
--
-- ALTERNATING, NEAREST FIRST, which is the same shape `beaterStartPosition` searches for a clear
-- spot with and the same shape the archived lane offsets had: one idiom in this repo for "deal these
-- out either side of a line".
function ForestTest.beaterLaneOffset(index: number?): number
	local which = (index or 1) - 1
	if which <= 0 then
		return 0
	end
	local step = math.ceil(which / 2) * ForestTest.BEATER.laneSpacingStuds
	return if which % 2 == 1 then step else -step
end

-- WHERE A BEATER STARTS, as flat geometry: north of the line's own spawn, on the push line through
-- `standX`. PURE -- the ground and the trunks are the server's to measure (`beaterStartPosition`).
function ForestTest.beaterStart(standX: number, sideOffset: number?): Vector3
	local x = standX + (sideOffset or 0)
	local north = ForestTest.LINE.spawnNorthStuds + ForestTest.BEATER.behindLineStuds
	return Vector3.new(x, ForestTest.CENTRE.Y, ForestTest.roadZ(x) + north)
end

-- WHICH WAY SHE LOOKS: at the road, straight down the push. The point on the curve at her own x,
-- which is also where the line she is behind is heading.
function ForestTest.roadPointAt(x: number): Vector3
	return Vector3.new(x, ForestTest.CENTRE.Y, ForestTest.roadZ(x))
end

-- WHERE A BOAR IS GONE. South of every point of the road: the curve's lowest z is CENTRE.Z - 30, so
-- 250 past that is clear of the whole length. `Brain:_outcome` despawns at `position.Z <= exitZ`.
ForestTest.EXIT_Z = ForestTest.CENTRE.Z - ForestTest.ROAD.amplitudeStuds - 250

-- WHERE THE BOARS WAIT. Karen: *"so wildboars will be located in different places"*. Each is a
-- point north of the road with a sounder size; the schedule below decides when each one moves.
--
-- SIZES ARE KAREN'S: *"we have make a groups 10 8 20 25"*, plus the lone big males she asked for.
--
-- THEY MOVED IN AND THEY MOVED CLOSER TO THE MIDDLE, and both are measured rather than tidied.
--
-- DISTANCE: at 240-450 studs a pushed herd needs minutes to reach the road, and Karen's whole test
-- is action inside 20 seconds. A flushed boar runs at roughly 20 studs a second, so 130-210 studs
-- is 7-11 seconds of running -- which lands a wave on the road inside the 20-second beat with time
-- to be seen coming.
--
-- SIDEWAYS: she stands at stand 5, x = 3030. The first spread ran to +-610, so the far ones crossed
-- 600 studs away and she would never have seen them. These sit within +-330, which at the road is
-- inside a few seconds' walk of her and well within sight down a 40-stud lane.
-- WHERE A WAVE IS RELEASED, relative to the stand the hunter actually locked (task 123 round 8).
-- With nobody playing, `standX` is the default stand's, which is what the drive used before.
function ForestTest.wavePoint(standX: number, spec): Vector3
	local x = standX + (spec.offsetX or 0)
	return Vector3.new(x, ForestTest.CENTRE.Y, ForestTest.roadZ(x) + (spec.northStuds or 100))
end

-- THE NAMED HOLDINGS ARE GONE (task 123 round 8), and what replaced them is above:
-- `ForestTest.wavePoint` plus the `offsetX`/`northStuds` the SCHEDULE now carries per wave.
--
-- They were six fixed points on the map -- west-hollow, centre-thicket, east-ridge, far-east and two
-- singles, 60 to 110 studs north of the road at x offsets of -300 to +330 from the map's centre --
-- and the indirection was a name in the schedule looked up in a table. It had to go because every
-- one of those x values was absolute: stands are 150 studs apart, so a wave released at a fixed
-- point could be 300 studs from the stand Karen had actually picked, and whether she ever got a
-- close crossing was luck. The distances they encoded (`northStuds` 60-110, which is 13-24 s at a
-- walk) are carried forward in the schedule's own numbers.

-- THE AMBIENT DRIVE: ACTION WITHOUT ANOTHER PLAYER.
--
-- Karen: *"let's make each 20s cross 1 flock then 1 big male then on other side few so to be
-- action"*, and *"several animals cross road / several go back"*. She is testing alone in the
-- morning, so nothing here may depend on a driver existing.
--
-- `turnsBack` IS THE HALF SHE ASKED FOR TWICE. A drive where every animal crosses is a shooting
-- gallery; the ones that come to the edge, think better of it and go back are what makes a hunter
-- wait. It is per-entry data so the rhythm is readable rather than random.
-- EVERY WAVE IS AIMED AT THE HUNTER (task 123 round 8). Karen, 2026-10-05: *"also they has to
-- cross close to me also / ... they has to cross like from left to right or opositi so I can shoot
-- straigh also not only on sides"*.
--
-- `offsetX` IS RELATIVE TO THE STAND SHE LOCKED, not to the middle of the map. Before this round the
-- holdings sat at fixed world positions and whether a crossing was near her was luck -- stands are
-- 150 studs apart, so a wave released at a fixed x could be 300 studs away from the one she picked.
-- `ForestTest.wavePoint` adds her stand's x to this, so "55 studs west of me" means that wherever
-- she stands.
--
-- `lateral` IS THE PASS ACROSS HER VIEW. She faces NORTH (+Z), so -- and this is the half that is
-- easy to get backwards -- her RIGHT is -X and her LEFT is +X (a CFrame looking down +Z has
-- RightVector -X). So a LEFT-TO-RIGHT pass travels from +X to -X, and `"LtoR"` means exactly that.
-- A lateral wave comes south to `WAVE.lateralDz` first, walks ACROSS her front for
-- `WAVE.lateralSpan` studs, and only then is pushed over the road -- which is the broadside shot she
-- asked for. It is a beater POSITION, not a new behaviour: see `ForestTest.beaterPosition`.
--
-- `composition` IS AN INDEX INTO `Boar.CONFIG.SOUNDER.COMPOSITIONS`, because who is in a flock is
-- the boar system's fact and which flock comes next is the drive's.
-- THE REPORTING WINDOW, AND NOTHING ELSE (task 124). This world has no drive to end, so it is given
-- one -- but it moves no animal and resets no schedule. "The next drive starts" here means exactly
-- one thing: the report's window rolls over. The wave cycle, the active waves, the boars on the ground
-- and the hunter's stand are all untouched, because resetting them would change the push rhythm Karen
-- accepted in task 123 and nothing asked for that.
--
-- 300 seconds is the Director's number: about fifteen waves at the 20 s interval.
ForestTest.DRIVE = { seconds = 300 }

-- ONE SIDE TO THE OTHER, IN A LINE (task 127). Karen, 2026-10-05: *"imagine they have to go from one
-- side to another / crossing roud with one line could be 2 i line ect how in real life ... imagine
-- they come from one side in one line and crossing road thats it"* -- and, about the whole thing,
-- *"it's simple"*.
--
-- THIS REPLACES THE WAVE BEHAVIOUR AND DOES NOT DELETE IT. With `enabled = false` the world does
-- exactly what tasks 122, 123 and 126 left it doing -- pushes, turn-backs, lateral passes, phantom
-- beaters -- and every one of those code paths is still there and still tested. One word switches
-- between them, because Karen has accepted parts of the old behaviour before and may want them back.
ForestTest.LINE = {
	enabled = true,

	-- HOW MANY LINES. *"could be 2 i line"* -- the Director's figure: about a quarter of waves come
	-- as two parallel lines, the rest as one.
	twoLineChance = 0.25,
	-- Two leaders this far apart across the direction of travel. 5 studs is a body's width plus a
	-- gap: close enough to read as one group, far enough that the two files do not merge.
	lineGapStuds = 5,

	-- NOSE TO TAIL IS 3 STUDS, AND THE STATION SPACING IS THEREFORE 8.5, because a boar is 5.5 studs
	-- long (`Boar.CONFIG.BODY_SIZE.Z`). The Director's figure is the GAP a hunter sees; this number is
	-- centre to centre, and the two are a body apart.
	--
	-- MEASURED, AND THE FIRST VERSION HAD IT WRONG. With `spacingStuds = 3` as a centre-to-centre
	-- station, eight 5.5-stud bodies were asked to stand 3 studs apart -- so they overlapped by 2.5
	-- studs each and the physics solver spent every frame shoving them out of one another. The line
	-- never settled: nose-to-nose gaps came out at a 9.9-stud median with a p90 of 176, 29 trunk
	-- contacts and 23 animals that moved less than a stud in three seconds. None of that was the
	-- following rule; all of it was eight animals standing inside each other.
	-- 8.5 STAYS, AND TASK 136 TRIED 6.5 AND MEASURED IT WORSE. The Director asked for "body length
	-- + ~1 stud, try ~6.5 if 8.5 still reads loose", which is the right instinct -- a boar is 5.5
	-- studs long, so 6.5 centre to centre is a one-stud nose-to-tail gap and 8.5 is three.
	--
	-- WHAT IT ACTUALLY DID, over 150 s of two-line waves, measured on the APPROACH AND THE CROSSING
	-- (the half of the trace north of the road, which is the half a hunter watches):
	--
	--                   offset median   p75           p90           gap median
	--   8.5 (this)        0.23 / 0.42   0.65 / 1.72   1.89 / 4.27   8.79 / 9.15
	--   6.5               0.77          1.97          4.02          7.39
	--
	-- BOTH RUNS OF 8.5 ARE CARRIED, AND THEY HAVE TO BE (round 2, the Reviewer's note -- round 1's
	-- comment quoted the better one as fact). They are the same build 150 s apart and they disagree
	-- by more than the difference being measured. So the honest reading is NOT "8.5 is twice as
	-- tight": it is that 6.5 closes the gap by a stud and a half, nothing here says the file gets
	-- laterally tighter for it, and one of the two 8.5 runs says it gets looser. 8.5 stays because it
	-- is the incumbent and 6.5 did not earn the change -- not because 6.5 was shown to be worse.
	-- Settling it needs a longer trace or a per-wave statistic; this was neither.
	spacingStuds = 8.5,
	-- HOW CLOSE A FOLLOWER MAY AIM TO THE ONE IN FRONT, measured along the trail: just short of its
	-- tail, which is what "no follower ever ahead of the one in front" means when the thing being
	-- regulated is an arc length.
	--
	-- IT WAS A BODY LENGTH FIRST, AND THAT BROKE THE LINE. An animal standing exactly where it
	-- belongs has the one ahead a station along, so with the 6.5-stud station this task was trying at
	-- the time, a 5.5-stud margin handed it a point 1.0 stud in front of its own nose -- inside `Boar.CONFIG.LINE.ARRIVE_STUDS`, which is 1.0. The Brain
	-- quite correctly answered "arrived", the animal stopped, the file walked on and the gap opened:
	-- MEASURED at 58 stuck and 18.2 % breaks against 15 and 9.0 % before the change. It is the same
	-- trap task 127 round 3 dug itself with `aim = min(ownS + lookahead, stationS)`, in a new place.
	--
	-- 1.5 studs bites only when a follower has closed to within a body length of the one ahead, which
	-- is the case it is for; the floor below (`minAimStuds`) makes sure it can never bite into a
	-- point the animal is already standing on.
	noOvertakeStuds = 1.5,
	-- A FOLLOWER IS NEVER AIMED AT A POINT UNDER ITS OWN FEET. Above
	-- `Boar.CONFIG.LINE.ARRIVE_STUDS` (1.0) by
	-- enough that an order is always a direction; the SPEED is what holds a closed-up animal back,
	-- which is `Line.followerSpeed`'s job and not the aim's.
	minAimStuds = 2.5,
	-- HOW LONG A WEDGED LEADER IS LEFT TO FREE HERSELF (task 136).
	--
	-- THE ASYMMETRY WAS THE BUG, AND IT COST A WHOLE FILE AT A TIME. A wedged FOLLOWER is put back on
	-- the trail -- a few studs onto ground the leader has already walked. A wedged LEADER was handed
	-- another route, computed from the position she is wedged IN, through the trunk she is wedged
	-- AGAINST; if the pathfinder answered the same way, she stayed there. MEASURED in a 150 s trace:
	-- `Boar6` sat at one point 17 studs north of the road for 110 SECONDS with an ordered speed of
	-- 24, and the stuck detector counted it every three seconds -- 464 of the run's stuck reports
	-- were a handful of animals doing exactly that, and the file behind each of them never crossed.
	--
	-- SO SHE IS LET GO OF, BRIEFLY. An ordered animal runs no whiskers and no wedge recovery, by
	-- design (task 127: the route was already checked for trunks). Dropping the order for a moment
	-- hands her back to `Brain`'s own machinery -- `steerAroundTrunk` and the `stuckTurn` sidestep,
	-- both of which are gated on `not ordered` and both of which exist to get an animal off a trunk.
	-- The drive takes her back when the window closes. Nothing new is invented here; a thing that was
	-- switched off for a good reason is switched on again for the one case that reason does not cover.
	leaderFreeSeconds = 1.5,
	-- HOW FAR ALONG THE TRAIL `Line.arcAt` will look for an animal, given where it was last step.
	-- Generous against one step of a running boar (RUN_SPEED is ~24 studs/s and the drive steps on
	-- Heartbeat), and far tighter than the length of a doubled-back loop round a trunk, which is
	-- what it exists to refuse.
	arcWindowStuds = 14,
	-- How far the leader walks between breadcrumbs. 1 stud is a third of the spacing, so a follower's
	-- station is interpolated between crumbs that are always close together.
	crumbStuds = 1,
	-- Inside this of its station a follower just matches the leader's speed; outside it, it closes at
	-- +-`catchup`. +-20 % is the Director's clamp: a line that closes gently instead of concertinaing.
	stationToleranceStuds = 1.5,
	-- +-40 % (the Director's round-2 figure, up from 20): a follower that has fallen behind has to be
	-- able to close faster than the line walks, or the gap is permanent.
	catchup = 0.4,
	-- HOW FAR ALONG THE TRAIL a follower aims each step. Short, because it is a straight-line order
	-- and the only guarantee is that the leader walked this bit: 4 studs is under a body length, so
	-- the chord it cuts is never wide enough to leave her path.
	lookaheadStuds = 4,
	-- THE SOW WAITS. Past this much arc-length lag on the LAST animal she eases toward `tailSlow` of
	-- her pace. 12 studs is about one and a half stations -- a gap a hunter would notice.
	tailPatienceStuds = 12,
	tailSlow = 0.45,

	-- THE PACE OF A WAVE, drawn once when it is released. *"then trot sometimes walk sometimes run"*
	-- -- so a trot is the common case and the other two are the variation. Weights, not percentages,
	-- so adding a fourth is one row.
	-- A CALM WAVE WALKS OR TROTS, AND NEVER RUNS (task 139 round 3). Karen, 2026-10-09: *"when no
	-- shoot not moving they come to road cal trot when spooked run and same when beater close"*.
	--
	-- `run` WAS A FIFTH OF ALL WAVES, drawn before anything had happened, so a hunter at a stand
	-- regularly watched a line come out of the trees at a flat gallop with nothing chasing it. A run
	-- is a REACTION in this world and it still happens: a shot inside `SENSE.SHOT_AUDIBLE_STUDS`, a
	-- beater inside the flush radius, or a hit -- all three reach `Brain:spook` and all three
	-- override the wave's pace. What this mix decides is only the pace of a wave that nothing has
	-- happened to yet, and the answer to that is a trot.
	paceMix = {
		{ pace = "walk", weight = 30 },
		{ pace = "trot", weight = 70 },
	},

	-- WHERE A LINE STARTS: this far north of the road, in the trees on the drive side.
	spawnNorthStuds = 180,
	-- ...and how far east or west of the hunter's own stand it crosses. Task 123 round 8's close/far
	-- choice, kept: some waves cross in front of her and some give her a longer shot.
	crossOffsets = { -70, -35, 20, 55, 95 },
	-- The line is spawned pointing at its crossing point, so the first thing a hunter sees is a file
	-- already aimed at the road rather than a group turning round.
	spawnSpreadStuds = 3,

	-- STUCK IS ZERO, AND THIS IS HOW IT IS CAUGHT. Karen: *"also I saw that some boars stuck in
	-- tree"*. An animal that has moved less than a stud in three seconds while it was asked to move
	-- is re-pathed (a leader) or snapped back onto the trail (a follower), and every occurrence is
	-- counted so "zero" is a number in the report rather than a hope.
	-- AND IT ONLY COUNTS WHILE THE ANIMAL WAS ASKED TO MOVE (task 127 round 2): a follower that has
	-- overrun its station is told to stand still on purpose, and standing still on purpose is not
	-- being stuck. 2 studs/s is below every gait this world uses and above the float noise of a
	-- speed that is meant to be zero.
	-- HOW CLOSE TO THE ROAD THE LEADER IS OFFERED HER LOOK (task 126 round 2). Karen: *"they can stop
	-- before entering the road"*. 45 studs is about two seconds at a trot, so the stop happens in the
	-- open where a hunter can see it rather than on the gravel; the Brain decides whether she takes
	-- it at all (`MOVE.EDGE_CHANCE`) and refuses outright if she is already frightened.
	checkWithinStuds = 45,
	-- WHERE THE DRIVE IS, FOR AN ANIMAL THAT HAS JUST CROSSED (task 139 round 3). Karen: *"and they
	-- run away when cross the road"*. `ForestTest.stepLines` spooks the member it is dropping and
	-- has to say what from; this is how far NORTH of it that is, so the Brain's one latched heading
	-- points south at `field.exitZ` and not back over the road. 40 studs is the width of the push
	-- behind a crossing line -- far enough to be the drive and not the animal's own shadow.
	runAwayFromStuds = 40,
	stuckAskedSpeed = 2,
	stuckSeconds = 3,
	stuckStuds = 1,

	-- How long a line lives before the drive gives up on it, whatever it is doing. A route of about
	-- 600 studs at a walk (4.5) is 130 s; this is the ceiling that stops a wedged wave living for ever.
	maxSeconds = 150,
}

-- ---------------------------------------------------------------- the wood is already full (154)
--
-- KAREN, 2026-10-11, on her first beater playtest: *"didn;t see any animals probably need to wait
-- 10s ?"* and then *"so animals already there somewhere in bushes close to trees ect"*.
--
-- SHE WAS RIGHT ABOUT THE WAIT AND THE DIRECTOR MEASURED IT: a wave is released every
-- `SCHEDULE.intervalSeconds` (20 s), and a beater put down `BEATER.behindLineStuds` behind the
-- line's own spawn walked the 240 studs to the road in about sixteen seconds at 15.7 studs/s -- so
-- she arrived BEFORE THE FIRST WAVE EXISTED and the wood she walked through was empty. (That 240 is
-- 580 since task 162 and the arithmetic is 37 s, which does not change the finding: a timer is
-- still the wrong shape for somebody who walks at the animals.)
--
-- A TIMER IS THE WRONG SHAPE FOR A BEATER, which is why this is not "release the first wave
-- sooner". A hunter stands still and the drive comes to him, so a schedule is exactly right for
-- him; a beater WALKS AT animals that are already lying up, and what she is testing is the moment
-- she finds them. So in beater mode there is no schedule at all: the wood is STOCKED when she
-- starts, and -- since task 172 -- never re-stocked: a wood is beaten once, and the re-stock was the
-- last way an animal could appear behind the line (see the end of `REST`). `ForestTest.stepRest` is
-- the whole of it.
--
-- THEY ARE RESTING, AND THAT IS NOTHING NEW EITHER. A sounder spawned and not ordered is an IDLE
-- sounder, and `CALM.ENABLED` -- on in this world -- is already the graze/stand/lie repertoire
-- (task 117). This file adds no behaviour; it only says where to put them.
ForestTest.REST = {
	-- WHERE A GROUP MAY BE PUT, as the band between her and the road. She starts at
	-- `LINE.spawnNorthStuds + BEATER.behindLineStuds` = 580 studs north of it, so a group inside this
	-- band is in front of her and short of the road -- which is both "between her and the road" and
	-- far enough from the verge that a hunter at a stand is not looking at a boar standing still.
	--
	-- (TASK 162's VERSION OF THIS PARAGRAPH IS HISTORY NOW, and it is kept as history rather than
	-- deleted: the band was 40-460 then, derived the same way from the one reach there was --
	-- `behindLineStuds 400 + spawnNorthStuds 180 - (SPOOK.BEATER_STUDS 89 + clearOfStartStuds 30)` =
	-- 461, taken down to 460. Task 172 split the reach in two and the derivation follows the NOTICE
	-- one, below.)
	nearRoadStuds = 40,
	-- 425, AND IT IS STILL DERIVED (task 172 moved it from 460). The band's far edge is as deep as
	-- the keep-away below allows, and the keep-away is now the NOTICE reach rather than the flush
	-- reach, because noticing is the first thing that happens to a group and a group that notices her
	-- before she has taken a step is the same defect task 162 measured in its flush form:
	--
	--   behindLineStuds 400 + spawnNorthStuds 180 - (SPOOK.NOTICE_STUDS 125 + clearOfStartStuds 30)
	--     = 425
	--
	-- `forest_stand.spec` asserts the relation, so the number cannot drift away from the reach.
	farRoadStuds = 425,

	-- ...AND NOT ALREADY INSIDE HER REACH. MEASURED, task 154's first run: the group nominally at
	-- `offsetX +45, northStuds 185` is sqrt(45^2 + 55^2) = 71 studs from where a beater is put down,
	-- which was inside the one reach there was then -- so it was latched and gone on the first
	-- heartbeat, before she had taken a step. A wood she has already emptied by standing in it is not
	-- a wood. One reach plus 30 studs is far enough that the nearest group is a walk away.
	clearOfStartStuds = 30,

	-- CLOSE TO A TRUNK, AND NOT INSIDE ONE. Karen: *"somewhere in bushes close to trees ect"*. A
	-- spot is taken when the nearest SOLID thing is at least `clearStuds` away (nothing is spawned
	-- inside a trunk) and at most `nearTrunkStuds` away (it is a spot in the trees and not out in
	-- the open). `roomToStand`'s own header is why "solid" is the test and a fern is not.
	clearStuds = 8,
	nearTrunkStuds = 22,

	-- ...AND ON THE GROUND. `Runtime:spawn` places every member at `world.groundAt`, which raycasts
	-- past `OurForest`/`Foliage` but NOT past the two `Session` folders of 831 more trees (task 153
	-- measured them) -- so that ray can stop on a canopy and drop a sounder out of a tree. A spot is
	-- refused when the terrain's own answer and that one disagree by more than this.
	canopySlackStuds = 6,

	-- ---------------------------------------------------------------- SEEN FROM THE LANE (task 172)
	--
	-- KAREN, 2026-10-13 ~09:20: *"beaters has to see more animals when walking ... I want to see them
	-- more"*. Two of the three answers to that are in this block; the third is the staged reaction in
	-- `SPOOK` above.
	--
	-- A SPOT IS PREFERRED WHEN THE LANE CAN SEE IT. `ForestTest.restSeenFromLane` casts one ray from
	-- the walking line -- the group's own lane, `sightFromStuds` short of it, at a walking man's eye
	-- height -- to the spot, and a spot with a trunk in the way is tried later than one without. It
	-- is a PREFERENCE and not a rule: the search's second pass drops it, because a wood where every
	-- legal spot happens to be screened is a wood with no animals in it, which is worse than a wood
	-- with one animal behind a tree.
	sightEyeStuds = 3.5, -- a standing man's eyes above the ground he is on
	sightTargetStuds = 2, -- ...and the animal's shoulder, not its feet
	sightFromStuds = 45, -- how far short of the group the look is taken from: inside the notice band
	-- ...AND HOW FAR OFF HIS LANE A GROUP MAY BE AT ALL. Every row below is within 24 studs of its
	-- own lane, and this is the ceiling that keeps it that way -- 40 studs is 11 m, about three
	-- lengths of the animal, so a group is beside the lane rather than somewhere in the wood.
	laneSideStuds = 40,

	-- How a spot is looked for: the nominal point first, then rings of eight around it. Deterministic
	-- on purpose -- the same wood gives the same answer twice, so a trace can be repeated.
	searchRings = 4,
	searchStepStuds = 16,

	-- The ring `spawnSounder` may spread a group over; the same 90 the wave path passes, and for the
	-- same reason (a sounder of 9 needs room not to spawn inside itself).
	spreadStuds = 90,

	-- ---------------------------------------------------------------- AND IT IS NEVER RE-STOCKED
	--
	-- KAREN, 2026-10-13 ~09:25, verbatim: *"and again no boar behing comming after beater walk"* --
	-- after task 168 had already made the line sweep what it passes.
	--
	-- THE RE-STOCK WAS THE ONE SOURCE 168 LEFT, AND 168 MEASURED IT ITSELF: *"7 animals of 25
	-- appeared up to 31 studs behind the front; the sweep caught them on the next tick and they ran
	-- out, but a group that has to be swept the instant it exists is a group Karen saw come from
	-- behind"*. The reason is geometric and no search can fix it: this band is measured from the
	-- ROAD, and fifteen seconds after the wood is empty the line is deep inside the band -- so the
	-- deep rows have nowhere left to go that is in front of anybody.
	--
	-- SO THE WOOD IS STOCKED ONCE AND STAYS AS SHE LEAVES IT, which is the dispatch's own words
	-- (*"no re-stock or spawn behind the line at all -- if the wood empties, it stays empty for this
	-- drive"*) and is also what a drive IS: a wood is beaten once. `restockSeconds` is gone with the
	-- behaviour it timed; `ForestTest.stepRest` now stocks on the first heartbeat of beater mode and
	-- never again, and `state.restStocked` is the latch that says so. The old row and the branch it
	-- timed are archived in `backups/2026-10-13_task-172_rest-restock.md`, with the reason, as rule 7
	-- asks.

	-- THE GROUPS, SPREAD ALONG THE LANES (task 172). `composition` indexes
	-- `Boar.CONFIG.SOUNDER.COMPOSITIONS` for the same reason the schedule does: who is in a flock is
	-- the boar system's fact and where they are lying up is this world's. `offsetX` is relative to the
	-- stand the drive aims at -- which is the x the line is walking at -- and `laneOffset` says WHICH
	-- lane of the line this group belongs to (`ForestTest.beaterLaneOffset` deals out 0, +150, -150,
	-- +300, -300), so a spot can be judged by what that lane will see of it.
	--
	-- 36 ANIMALS IN TEN GROUPS, up from 28 in six. Karen: *"make them a lot not too much to break
	-- but enough to test"* and now *"I want to see them more"*. `MAX_BOARS` is 60 and a measured
	-- session has carried 32 at once in this place, so 36 is more wood than she has played and inside
	-- what the place has shown it can hold.
	--
	-- FOUR OF THE TEN ARE ON HER OWN LANE (`laneOffset = 0`, which is always the real beater's --
	-- `beaterLaneOffset` gives index 1 the middle), 110 studs apart down the whole 355-stud depth of
	-- the walk, so she meets a group about every twenty-five seconds at a beater's pace. The other
	-- six are on the two lanes either side of her, within 24 studs of them, so the bot beaters' walks
	-- produce encounters she can see across the front instead of an empty wood on both sides.
	--
	-- AND NEVER TWO AT ONCE, which is what the depths and the offsets are spaced for: the flush reach
	-- is `SPOOK.BEATER_STUDS` (71) and the fright LATCHES, so two groups inside 71 studs of each other
	-- both bolt on one approach. MEASURED over all 45 pairs in the world frame -- which is not the
	-- same as the depth difference, because the road is a sine and `restPoint` adds `roadZ(x)`: the
	-- closest pair is 101.3 studs (rows 1 and 2, both on her lane), which clears the reach by 30.
	-- `forest_stand.spec` asserts no pair is inside the reach with the ring search's own margin.
	groups = {
		{
			offsetX = -18,
			laneOffset = 0,
			northStuds = 415,
			composition = 6,
			note = "a lone big male, the first thing she meets",
		},
		{
			offsetX = 22,
			laneOffset = 0,
			northStuds = 305,
			composition = 5,
			note = "a sow and her young, deep on her lane",
		},
		{
			offsetX = -20,
			laneOffset = 0,
			northStuds = 195,
			composition = 2,
			note = "two males, half way down her lane",
		},
		{
			offsetX = 24,
			laneOffset = 0,
			northStuds = 85,
			composition = 1,
			note = "a mixed flock on her lane, close to the road",
		},
		{
			offsetX = 132,
			laneOffset = 150,
			northStuds = 370,
			composition = 2,
			note = "two males, deep on the east lane",
		},
		{ offsetX = 168, laneOffset = 150, northStuds = 230, composition = 5, note = "a sow and her young, east" },
		{
			offsetX = 140,
			laneOffset = 150,
			northStuds = 90,
			composition = 6,
			note = "a lone male, east and close to the road",
		},
		{
			offsetX = -168,
			laneOffset = -150,
			northStuds = 340,
			composition = 6,
			note = "a lone male, deep on the west lane",
		},
		{ offsetX = -132, laneOffset = -150, northStuds = 200, composition = 2, note = "two males, west" },
		{
			offsetX = -162,
			laneOffset = -150,
			northStuds = 60,
			composition = 5,
			note = "a sow and her young, west and close to the road",
		},
	},
}

-- WHERE A RESTING GROUP IS NOMINALLY PUT, before the ground and the trunks are measured. PURE, the
-- same division `wavePoint` has: the arithmetic here, the world's own answer in
-- `ForestTest.restSpot`.
function ForestTest.restPoint(standX: number, spec, sideOffset: number?, outOffset: number?): Vector3
	local x = standX + (spec.offsetX or 0) + (sideOffset or 0)
	local north = (spec.northStuds or 120) + (outOffset or 0)
	return Vector3.new(x, ForestTest.CENTRE.Y, ForestTest.roadZ(x) + north)
end

-- WHERE A BEATER IS STANDING WHEN HE OUGHT TO SEE THIS GROUP (task 172). PURE: the point on the
-- group's own lane, `sightFromStuds` short of it along the walk, at the ground's z for that x -- the
-- same division `restPoint` has, arithmetic here and the raycast in `ForestTest.restSeenFromLane`.
--
-- `sightFromStuds` IS INSIDE THE NOTICE BAND ON PURPOSE (45 studs against 125): the question this
-- point asks is not "can he see it from anywhere" but "can he see it from where he will be standing
-- when it puts its head up", and the answer has to be taken from inside the band or it is about a
-- different moment.
function ForestTest.laneLookPoint(standX: number, spec, spot: Vector3, rest): Vector3
	local laneX = standX + (spec.laneOffset or 0)
	local resolved = rest or ForestTest.REST
	local north = spot.Z - ForestTest.roadZ(spot.X) + (resolved.sightFromStuds or 0)
	return Vector3.new(laneX, ForestTest.CENTRE.Y, ForestTest.roadZ(laneX) + north)
end

-- HOW FAR OFF ITS OWN LANE A GROUP'S SPOT IS. PURE, flat, and the one thing `laneSideStuds` is
-- compared against -- so "beside the lane" is measured in one place.
function ForestTest.offLaneStuds(standX: number, spec, spot: Vector3): number
	return math.abs(spot.X - (standX + (spec.laneOffset or 0)))
end

ForestTest.SCHEDULE = {
	intervalSeconds = 20,
	cycle = {
		-- Close, straight down across the road: 2 females, 3 males, 4 cubs.
		{ offsetX = -55, northStuds = 95, composition = 1, turnsBack = false, note = "a mixed flock, close and west" },
		-- Across her front, left to right, then over the road.
		{
			offsetX = 95,
			northStuds = 115,
			composition = 3,
			lateral = "LtoR",
			turnsBack = false,
			note = "five males and three females, across the front left to right",
		},
		-- Far out on the east, so it is not always the same spot.
		{ offsetX = 140, northStuds = 100, composition = 4, turnsBack = false, note = "sows and piglets, far east" },
		-- Across her front the other way.
		{
			offsetX = -95,
			northStuds = 115,
			composition = 2,
			lateral = "RtoL",
			turnsBack = false,
			note = "two males, across the front right to left",
		},
		-- Close again, and this one thinks better of it.
		{
			offsetX = 45,
			northStuds = 90,
			composition = 5,
			turnsBack = true,
			note = "a sow and her young, close, and back",
		},
		-- The lone big male, close enough to be worth the barrel.
		{ offsetX = -40, northStuds = 85, composition = 6, turnsBack = false, note = "one big lone male, close" },
	},
	-- HOW FAR SHORT OF THE ROAD A TURNED-BACK GROUP STOPS before it goes home. Close enough for the
	-- hunter to see it and raise the gun, which is the whole point of letting it refuse.
	turnBackStuds = 70,
}

-- WHERE THE GROUND IS, ASKED OF THE WORLD ITSELF.
--
-- `Boar`'s `field.groundY` is ONE number for a whole field. That is true of the generated map, whose
-- drive corridor is flat, and FALSE here: MEASURED in this place, the ground is y 140 at the road,
-- 149 at 200 studs north and 196 at 400. Every boar released up there was spawned at 140 -- inside
-- the hill -- which is why they stood still and why fresh ones vanished within a second.
--
-- `Runtime:spawn` now asks the world through `world.groundAt`, a seam the boar's own comment
-- predicted and deferred. A world that does not supply one behaves exactly as before.
--
-- A PERSON IS NOT GROUND, AND IT IS THE SAME RULE `ForestTest.roomToStand` ALREADY MAKES
-- (*"A PLAYER IS NOT AN OBSTACLE"*). One rule, one function, two callers: a question about a person
-- answered twice is how two systems end up disagreeing about what a person is.
--
-- IT WALKS UP, because a hit is not always the character itself: a hat's `Handle` is parented to an
-- `Accessory`, which is parented to the character, so the hit's immediate `Parent` has no Humanoid
-- and a parent-only test would call a hat the ground.
--
-- Returns the character MODEL (what a raycast filter needs), or nil.
function ForestTest.characterOf(instance: Instance?): Model?
	local node: Instance? = instance
	while node ~= nil and node ~= Workspace do
		if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") ~= nil then
			return node :: Model
		end
		node = node.Parent
	end
	return nil
end

-- HOW MANY BODIES ONE COLUMN MAY HOLD before this gives up and answers "no ground here". Eight is
-- already absurd -- a drive is at most sixteen players and they are spread along a line -- and the
-- bound exists so a raycast loop can never be unbounded, not because anybody expects to use it.
ForestTest.MAX_BODIES_IN_A_COLUMN = 8

-- IT IGNORES THE FOREST, THE ANIMALS AND THE PEOPLE. A boar must be put on the GROUND, not on a
-- fern, not on the back of the boar spawned a moment earlier -- and not on a player's head.
--
-- THE LAST ONE IS MEASURED AND IT STOPPED A PLAYTEST (task 158a(f), fixed in task 158). The drive
-- PUTS a beater on the beater pad and holds her there, and the next read of the markers cast this
-- ray down the same column: it hit `<player>.Head` at y 161.09 where the terrain is 155.81, a
-- 5.3-stud delta against `Markers.GROUND_TOLERANCE_STUDS` of 1 -- so `forest:beater-start` was
-- refused, and the Forest Test sat in `Waiting` for ever after its first drive. A standing person
-- must not change the world's answer about where the ground is.
--
-- A CHARACTER IS SKIPPED AND THE RAY CARRIES ON, rather than every character being excluded up
-- front: this module is shared and knows nothing about `Players`, and the rule it applies is about
-- what was HIT -- which covers a dog, an NPC or anything else with a Humanoid, the day one exists.
function ForestTest.groundAt(x: number, z: number): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, name in ipairs({ "OurForest", "Foliage", "Boars" }) do
		local found = Workspace:FindFirstChild(name)
		if found then
			table.insert(ignore, found)
		end
	end
	params.FilterDescendantsInstances = ignore
	for _ = 1, ForestTest.MAX_BODIES_IN_A_COLUMN + 1 do
		local hit = Workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1200, 0), params)
		if hit == nil then
			return nil
		end
		local character = ForestTest.characterOf(hit.Instance)
		if character == nil then
			return hit.Position.Y
		end
		table.insert(ignore, character)
		params.FilterDescendantsInstances = ignore
	end
	return nil
end

-- HOW MANY BOARS MAY EXIST AT ONCE. Karen: *"make them a lot not too much to break but enough to
-- test"*. The number itself is MEASURED on the machine and lives in the server system's own
-- report, not guessed here; this is the ceiling it may not exceed whatever it measures.
ForestTest.MAX_BOARS = 60

return ForestTest
