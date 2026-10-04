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
ForestTest.HOLDING = {
	{ name = "west-hollow", offsetX = -300, northStuds = 185, size = 10 },
	{ name = "centre-thicket", offsetX = -90, northStuds = 160, size = 8 },
	{ name = "east-ridge", offsetX = 150, northStuds = 175, size = 20 },
	{ name = "far-east", offsetX = 330, northStuds = 205, size = 25 },
	{ name = "west-single", offsetX = -170, northStuds = 135, size = 1 },
	{ name = "east-single", offsetX = 230, northStuds = 145, size = 1 },
}

function ForestTest.holdingPosition(entry): Vector3
	local x = ForestTest.CENTRE.X + entry.offsetX
	return Vector3.new(x, ForestTest.CENTRE.Y, ForestTest.roadZ(x) + entry.northStuds)
end

-- THE AMBIENT DRIVE: ACTION WITHOUT ANOTHER PLAYER.
--
-- Karen: *"let's make each 20s cross 1 flock then 1 big male then on other side few so to be
-- action"*, and *"several animals cross road / several go back"*. She is testing alone in the
-- morning, so nothing here may depend on a driver existing.
--
-- `turnsBack` IS THE HALF SHE ASKED FOR TWICE. A drive where every animal crosses is a shooting
-- gallery; the ones that come to the edge, think better of it and go back are what makes a hunter
-- wait. It is per-entry data so the rhythm is readable rather than random.
ForestTest.SCHEDULE = {
	intervalSeconds = 20,
	-- The cycle repeats. `holding` names a `HOLDING` entry; `size` overrides how many of it move.
	cycle = {
		{ holding = "east-ridge", size = 6, turnsBack = false, note = "a flock across the middle" },
		{ holding = "west-single", size = 1, turnsBack = false, note = "one big lone male" },
		{ holding = "centre-thicket", size = 3, turnsBack = true, note = "three come down and go back" },
		{ holding = "far-east", size = 8, turnsBack = false, note = "a big flock on the east side" },
		{ holding = "east-single", size = 1, turnsBack = true, note = "a male thinks better of it" },
		{ holding = "west-hollow", size = 5, turnsBack = false, note = "five across the west end" },
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
