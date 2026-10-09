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
	-- HOW FAR HE MAY THEN MOVE. "a few steps" -- a Roblox character walks 16 studs a second, so 6
	-- studs is about a third of a second of walking: enough to turn and shift his feet, not enough
	-- to leave the stand or crowd his neighbour.
	leashStuds = 6,
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
-- IT IGNORES THE FOREST AND THE ANIMALS. A boar must be put on the GROUND, not on a fern or on the
-- back of the boar spawned a moment earlier.
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
	local hit = Workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1200, 0), params)
	return if hit then hit.Position.Y else nil
end

-- HOW MANY BOARS MAY EXIST AT ONCE. Karen: *"make them a lot not too much to break but enough to
-- test"*. The number itself is MEASURED on the machine and lives in the server system's own
-- report, not guessed here; this is the ceiling it may not exceed whatever it measures.
ForestTest.MAX_BOARS = 60

return ForestTest
