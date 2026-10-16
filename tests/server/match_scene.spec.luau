-- match_scene.spec: the end of a drive and the results scene, as ARITHMETIC -- no drive, no players,
-- no boars, no clock and (except in the last describe) no Instance.
--
-- Everything this file drives is pure and exported for exactly that reason: `Match.crossedLine` (has
-- this beater crossed the hunters' line), `Match.gatherSpotFor` (where the animals are gathered and
-- which way the scene faces) and `Match.Scene`'s three layouts (the row, the ring, the four corners).
-- The two numbers they produce are then compared by `Phase.beatersThrough`, which match_phase.spec
-- drives.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/drive.md
-- Note:   docs/research/2026-10-12-drive-end-and-results-scene.md
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Match = require(ServerScriptService:WaitForChild("Match"))
local Scene = Match.Scene
local TestKit = require(game:GetService("ReplicatedStorage"):WaitForChild("TestKit"))

-- This spec's own numbers, short enough to read in a failure message. The shape is `Match.CONFIG`'s:
-- a `SCENE` block plus the one number the ring shares with the drive's placement.
local CONFIG = {
	STAND_HEIGHT_STUDS = 3.5,
	BEATER_CROSS_MARGIN_STUDS = 10,
	SCENE = {
		ENABLED = true,
		GATHER_BEHIND_STUDS = 24,
		SPACING_STUDS = 6,
		MAX_ANIMALS = 4,
		-- TASK 168: several rows. FOUR to a row here, which is this spec's own `MAX_ANIMALS`, so every
		-- case written before task 168 is still asking about ONE row and did not have to change.
		-- The several-rows cases use the SHIPPED numbers (`LIVE` below) instead, because what they are
		-- about is Karen's own bag sizes.
		PER_ROW = 4,
		ROW_SPACING_STUDS = 8,
		RING_RADIUS_STUDS = 14,
		RING_MARGIN_STUDS = 6,
		CORNER_STUDS = 16,
		CORNER_MARGIN_STUDS = 2,
		ANIMAL_SIZE = Vector3.new(1.6, 1.4, 4.0),
		ANIMAL_SCALES = { male = 1.0, female = 0.85, cub = 0.45 },
		ANIMAL_COLOR = Color3.fromRGB(58, 48, 42),
		POST_SIZE = Vector3.new(0.6, 10, 0.6),
		POST_COLOR = Color3.fromRGB(70, 60, 50),
		LIGHT_COLOR = Color3.fromRGB(255, 190, 120),
		LIGHT_BRIGHTNESS = 4,
		LIGHT_RANGE_STUDS = 60,
		FLAME_SIZE = Vector3.new(0.9, 0.9, 0.9),
		FLAME_COLOR = Color3.fromRGB(255, 200, 130),
		FIRE_SIZE = 4,
		FIRE_HEAT = 9,
		FIRE_COLOR = Color3.fromRGB(255, 160, 60),
		FIRE_SECONDARY_COLOR = Color3.fromRGB(120, 40, 10),
	},
}

-- THE SHIPPED NUMBERS, for the three cases that are about Karen's own bag sizes (1, 5 and 12) rather
-- than about the arithmetic: `MAX_ANIMALS` 4 above would cap a twelve-animal drive at four and the
-- case would prove nothing.
local LIVE = Match.CONFIG

-- THE DEV ARENA'S GEOMETRY, as plain tables: the drive consumes a post as a thing with a `Position`
-- and a `Size`, which is what lets this spec state the whole rule without building anything.
-- The line's normal points AT THE BEATERS (`Markers.read`), so the beaters stand at +Z.
local LINE = { position = Vector3.new(0, 10, 0), normal = Vector3.new(0, 0, 1) }
local POSTS = {
	{ Position = Vector3.new(-60, 11, 0), Size = Vector3.new(6, 2, 6) },
	{ Position = Vector3.new(0, 11, 0), Size = Vector3.new(6, 2, 6) },
	{ Position = Vector3.new(60, 11, 0), Size = Vector3.new(6, 2, 6) },
}

-- A CURVED ROAD, which is the forest's: three stands whose z wanders either side of one plane. The
-- plane sits at z = 0 and stand 3 really stands 30 studs north of it.
local CURVED_POSTS = {
	{ Position = Vector3.new(-60, 11, -30), Size = Vector3.new(6, 2, 6) },
	{ Position = Vector3.new(0, 11, 0), Size = Vector3.new(6, 2, 6) },
	{ Position = Vector3.new(60, 11, 30), Size = Vector3.new(6, 2, 6) },
}

return function()
	describe("has this beater crossed the hunters' line", function()
		it("says no while he is still up the drive, and yes once he is past them", function()
			-- The beaters start at +Z, which is where the line's normal points.
			expect(Match.crossedLine(Vector3.new(0, 11, 240), LINE, POSTS, 10)).to.equal(false)
			expect(Match.crossedLine(Vector3.new(0, 11, 20), LINE, POSTS, 10)).to.equal(false)
			-- ON the line is not across it, and neither is a stride past it: the margin is the rule.
			expect(Match.crossedLine(Vector3.new(0, 11, 0), LINE, POSTS, 10)).to.equal(false)
			expect(Match.crossedLine(Vector3.new(0, 11, -9), LINE, POSTS, 10)).to.equal(false)
			expect(Match.crossedLine(Vector3.new(0, 11, -10), LINE, POSTS, 10)).to.equal(true)
			expect(Match.crossedLine(Vector3.new(0, 11, -60), LINE, POSTS, 10)).to.equal(true)
		end)

		it("ignores how high he is and how far along the line he is", function()
			-- The verdict is the signed distance ACROSS the line and nothing else, so a beater walking
			-- past stand 1 is judged against stand 1.
			expect(Match.crossedLine(Vector3.new(-60, 300, -40), LINE, POSTS, 10)).to.equal(true)
			expect(Match.crossedLine(Vector3.new(999, 11, -40), LINE, POSTS, 10)).to.equal(true)
			expect(Match.crossedLine(Vector3.new(-60, 11, 40), LINE, POSTS, 10)).to.equal(false)
		end)

		it("measures against the NEAREST STAND, which is what makes a curved road honest", function()
			-- THE CASE THE PLANE ALONE GETS WRONG (docs/design/forest-drive.md section 6.1): the
			-- forest's line is ONE plane for a sine road, so at stand 3 the real road is 30 studs
			-- north of it. A beater who has walked 15 studs past stand 3 -- genuinely through the
			-- hunters' line -- is still at z = +15, on the beaters' side of the plane.
			local pastStandThree = Vector3.new(60, 11, 15)
			expect(Match.crossedLine(pastStandThree, LINE, CURVED_POSTS, 10)).to.equal(true)
			-- ...and the plane on its own, with no stands to measure against, says he has not.
			expect(Match.crossedLine(pastStandThree, LINE, nil, 10)).to.equal(false)
			-- The same beater standing 5 studs SHORT of stand 3 has not crossed it either way.
			expect(Match.crossedLine(Vector3.new(60, 11, 35), LINE, CURVED_POSTS, 10)).to.equal(false)
		end)

		it("answers no when there is no line, no normal and no position", function()
			-- A world whose markers are incomplete cannot end a drive early: the drive stays on its
			-- clock, which is the behaviour before this task.
			expect(Match.crossedLine(Vector3.new(0, 11, -400), nil, POSTS, 10)).to.equal(false)
			expect(Match.crossedLine(Vector3.new(0, 11, -400), { position = LINE.position }, POSTS, 10)).to.equal(false)
			expect(
				Match.crossedLine(
					Vector3.new(0, 11, -400),
					{ position = LINE.position, normal = Vector3.zero },
					POSTS,
					10
				)
			).to.equal(false)
			expect(Match.crossedLine(nil, LINE, POSTS, 10)).to.equal(false)
		end)
	end)

	describe("where the drive is gathered", function()
		it("is behind the middle stand, on the hunters' own side of the line, at the stand's ground", function()
			local spot, facing = Match.gatherSpotFor({ posts = POSTS, line = LINE }, CONFIG)
			expect(spot).to.be.ok()
			expect(facing).to.be.ok()
			-- The middle of three is stand 2, at x = 0.
			expect(spot.X).to.equal(0)
			-- BEHIND: the normal points at the beaters, so the spot is on the other side of the line.
			expect(spot.Z).to.equal(-CONFIG.SCENE.GATHER_BEHIND_STUDS)
			-- THE GROUND IS THE POST'S OWN UNDERSIDE, not its centre: 11 - 2/2 = 10.
			expect(spot.Y).to.equal(10)
			-- ...and the scene faces up the drive, which is where everybody has just been looking.
			expect(facing).to.equal(Vector3.new(0, 0, 1))
		end)

		it("has nowhere to gather with no stands at all", function()
			local spot = Match.gatherSpotFor({ posts = {}, line = LINE }, CONFIG)
			expect(spot).to.equal(nil)
			expect((Match.gatherSpotFor(nil, CONFIG))).to.equal(nil)
		end)

		it("gathers behind the stands even when the world has no line", function()
			-- A set with stands and no line is not a set the drive runs on (`complete` is false), but
			-- the arithmetic must not throw: +Z is the fallback, which is the DEV arena's own normal.
			local spot, facing = Match.gatherSpotFor({ posts = POSTS }, CONFIG)
			expect(spot).to.be.ok()
			expect(facing).to.equal(Vector3.new(0, 0, 1))
			expect(spot.Z).to.equal(-CONFIG.SCENE.GATHER_BEHIND_STUDS)
		end)
	end)

	-- TASK 191: KAREN, 2026-10-15 ~17:20, *"next is when hunt over everyone is in clean ground no
	-- grass firstable / second it could be next to cabin"*. The gathering is no longer always the
	-- drive's own spot behind the stands: the WORLD gets first say, and the rule above is the
	-- fallback. `Match.gatherSpotOf` is that choice, pure in the world's reader, so every way a
	-- world can get it wrong is a line here rather than a drive nobody watched.
	--
	-- Borrowed whole from ioquake3's `FindIntermissionPoint` (GPL-2.0): the authored point first,
	-- `if ( !ent )` the derived one. Note: docs/research/2026-10-16-gathering-at-the-cabin.md
	describe("who decides where the drive gathers", function()
		local MARKERS = { posts = POSTS, line = LINE }
		local YARD = Vector3.new(2798, 150, -2940)
		local EAST = Vector3.new(1, 0, 0)

		it("takes the world's own spot when there is one, and says so", function()
			local at, facing, fromWorld = Match.gatherSpotOf(function()
				return YARD, EAST
			end, MARKERS, CONFIG)
			expect(at).to.equal(YARD)
			expect(facing).to.equal(EAST)
			expect(fromWorld).to.equal(true)
		end)

		it("falls back to behind the middle stand when the world names nowhere", function()
			-- THE DEV PLACE, AND A FOREST TEST WHOSE LOBBY DID NOT BUILD. Both inject nothing (nil)
			-- or answer nothing, and both must get the game exactly as it was before this task --
			-- which is the "reachable by parameter" half of CLAUDE.md's flag rule, with no flag.
			for _, reader in ipairs({
				{ what = "no reader at all", fn = nil },
				{ what = "a reader that answers nothing", fn = function() end },
				{
					what = "a reader that answers a spot and no facing",
					fn = function()
						return YARD
					end,
				},
				{
					what = "a reader that answers something that is not a Vector3",
					fn = function()
						return 7, "east"
					end,
				},
				{
					what = "a reader that throws",
					fn = function()
						error("no lobby here")
					end,
				},
			}) do
				local at, facing, fromWorld = Match.gatherSpotOf((reader :: any).fn, MARKERS, CONFIG)
				expect(fromWorld).to.equal(false)
				-- ...and it is the drive's own answer, not nil: a world that cannot name a spot must
				-- still get Karen's scene, behind the middle stand, where it has always been.
				expect(at).to.be.ok()
				expect(facing).to.equal(Vector3.new(0, 0, 1))
				expect((at :: Vector3).Z).to.equal(-CONFIG.SCENE.GATHER_BEHIND_STUDS)
			end
			TestKit.note("match_scene: five ways a world can name nowhere, five falls back to the stands")
		end)

		it("answers nowhere only when BOTH rules do", function()
			-- A world with no reader AND no stands: `applyScene`'s own `scenesNowhere` branch, which
			-- is the one place "there is nowhere to gather" is decided.
			local at, facing, fromWorld = Match.gatherSpotOf(nil, { posts = {}, line = LINE }, CONFIG)
			expect(at).to.equal(nil)
			expect(facing).to.equal(nil)
			expect(fromWorld).to.equal(false)
			-- ...and a world that NAMES one still gathers, with no stands anywhere in it. That is the
			-- lobby case: the gathering yard is 570 studs from the drive and owes it no geometry.
			local named, namedFacing = Match.gatherSpotOf(function()
				return YARD, EAST
			end, { posts = {} }, CONFIG)
			expect(named).to.equal(YARD)
			expect(namedFacing).to.equal(EAST)
		end)

		it("the facing it is handed is the axis the row lies across", function()
			-- WHY THE YARD FACES THE LODGE (`Lobby.CONFIG.GATHER.FACING` = +X). `Scene.sideAxis`
			-- crosses the facing with +Y, so a look of +X gives a row axis of +Z: the animals lie
			-- north-south and a player arriving from the EAST -- the porch -- sees the whole row
			-- broadside rather than end-on. This is the arithmetic behind that sentence.
			local side = Scene.sideAxis(EAST)
			expect(math.abs(side.X) < 1e-6).to.equal(true)
			expect(math.abs(math.abs(side.Z) - 1) < 1e-6).to.equal(true)
			local row = Scene.rowLayout(YARD, EAST, 3, CONFIG)
			-- Every animal at the same x, stepping in z: the row runs across the viewer's line of sight.
			for index = 1, #row do
				expect(math.abs(row[index].Position.X - YARD.X) < 1e-6).to.equal(true)
			end
			expect(math.abs(row[2].Position.Z - row[1].Position.Z)).to.equal(CONFIG.SCENE.SPACING_STUDS)
		end)
	end)

	describe("the scene's layout", function()
		local spot = Vector3.new(0, 10, -24)
		local facing = Vector3.new(0, 0, 1)

		it("lays the animals in a row, centred on the spot and evenly spaced", function()
			local row = Scene.rowLayout(spot, facing, 4, CONFIG)
			expect(#row).to.equal(4)
			-- ACROSS the drive, so the row is seen side-on by everybody standing round it.
			for index = 2, #row do
				local step = (row[index].Position - row[index - 1].Position).Magnitude
				expect(math.abs(step - CONFIG.SCENE.SPACING_STUDS) < 1e-3).to.equal(true)
				expect(math.abs(row[index].Position.Z - spot.Z) < 1e-3).to.equal(true)
			end
			-- CENTRED: the row's own middle is the gathering spot.
			local middle = (row[1].Position + row[#row].Position) / 2
			expect((middle - spot).Magnitude < 1e-3).to.equal(true)
			-- ...and one animal stands exactly on it.
			local one = Scene.rowLayout(spot, facing, 1, CONFIG)
			expect(#one).to.equal(1)
			expect((one[1].Position - spot).Magnitude < 1e-3).to.equal(true)
			expect(#Scene.rowLayout(spot, facing, 0, CONFIG)).to.equal(0)
		end)

		it("sizes an animal by its kind, and an unknown kind like a male", function()
			local male = Scene.animalSize("male", CONFIG)
			expect(male).to.equal(CONFIG.SCENE.ANIMAL_SIZE)
			expect(Scene.animalSize("cub", CONFIG).Z < male.Z).to.equal(true)
			expect(Scene.animalSize("female", CONFIG).Z < male.Z).to.equal(true)
			expect(Scene.animalSize("cub", CONFIG).Z > 0).to.equal(true)
			expect(Scene.animalSize(nil, CONFIG)).to.equal(male)
			expect(Scene.animalSize("roe-deer", CONFIG)).to.equal(male)
		end)

		it("stands every player in a ring round the animals, all of them looking at the middle", function()
			local ring = Scene.ringLayout(spot, 6, CONFIG)
			expect(#ring).to.equal(6)
			local centre = spot + Vector3.new(0, CONFIG.STAND_HEIGHT_STUDS, 0)
			for _, at in ipairs(ring) do
				-- ON the circle, to the stud.
				local flat = Vector3.new(at.Position.X - centre.X, 0, at.Position.Z - centre.Z)
				expect(math.abs(flat.Magnitude - CONFIG.SCENE.RING_RADIUS_STUDS) < 1e-3).to.equal(true)
				-- AS HIGH AS A HUNTER ON A STAND: the drive's own placement number.
				expect(math.abs(at.Position.Y - centre.Y) < 1e-3).to.equal(true)
				-- FACING THE MIDDLE: the look vector points back at the centre.
				local toCentre = (centre - at.Position).Unit
				expect(at.LookVector:Dot(toCentre) > 0.999).to.equal(true)
			end
			-- Two players stand opposite each other, which is the ring working at the smallest size
			-- anybody will actually play.
			local two = Scene.ringLayout(spot, 2, CONFIG)
			expect(#two).to.equal(2)
			expect((two[1].Position - two[2].Position).Magnitude > CONFIG.SCENE.RING_RADIUS_STUDS).to.equal(true)
			expect(#Scene.ringLayout(spot, 0, CONFIG)).to.equal(0)
		end)

		it("puts the lights on FOUR corners, which is Karen's number", function()
			local corners = Scene.cornerPositions(spot, facing, CONFIG)
			expect(#corners).to.equal(4)
			local seen = {}
			for _, corner in ipairs(corners) do
				-- A square: both offsets are the corner distance, so each lamp is outside the ring.
				local offset = corner - spot
				expect(math.abs(math.abs(offset.X) - CONFIG.SCENE.CORNER_STUDS) < 1e-3).to.equal(true)
				expect(math.abs(math.abs(offset.Z) - CONFIG.SCENE.CORNER_STUDS) < 1e-3).to.equal(true)
				expect(offset.Magnitude > CONFIG.SCENE.RING_RADIUS_STUDS).to.equal(true)
				local key = string.format("%d,%d", math.floor(corner.X + 0.5), math.floor(corner.Z + 0.5))
				expect(seen[key]).to.equal(nil) -- four DIFFERENT corners, not one corner four times
				seen[key] = true
			end
		end)
	end)

	describe("the animals in several rows (task 168)", function()
		local spot = Vector3.new(0, 10, -24)
		local facing = Vector3.new(0, 0, 1)

		-- KAREN, 2026-10-12 ~21:45: *"animals layed down in front in several lines if more"*.

		it("lays 1, 5 and 12 animals out in 1, 1 and 2 rows with the shipped numbers", function()
			expect(Scene.perRow(LIVE)).to.equal(6)
			expect(Scene.rowCount(0, LIVE)).to.equal(0)
			expect(Scene.rowCount(1, LIVE)).to.equal(1)
			expect(Scene.rowCount(5, LIVE)).to.equal(1)
			expect(Scene.rowCount(6, LIVE)).to.equal(1)
			expect(Scene.rowCount(7, LIVE)).to.equal(2)
			expect(Scene.rowCount(12, LIVE)).to.equal(2)
			-- ...and the cap is a whole number of rows, so the block is never a row of one.
			expect(LIVE.SCENE.MAX_ANIMALS % Scene.perRow(LIVE)).to.equal(0)
		end)

		it("keeps one row exactly where it was, and centres every row on the spot", function()
			-- ONE ROW IS THE SCENE KAREN HAS ALREADY SEEN: five animals, 6 studs apart, centred.
			local row = Scene.rowLayout(spot, facing, 5, LIVE)
			expect(#row).to.equal(5)
			local side = Scene.sideAxis(facing)
			for index = 1, 5 do
				local offset = row[index].Position - spot
				-- Still on the spot's own depth: one row has no depth to spread into.
				expect(math.abs(offset:Dot(Vector3.new(facing.X, 0, facing.Z).Unit)) < 1e-3).to.equal(true)
				expect(math.abs(offset:Dot(side) - (index - 3) * LIVE.SCENE.SPACING_STUDS) < 1e-3).to.equal(true)
			end
			-- ...AND THE MIDDLE OF AN EVEN ROW STRADDLES THE SPOT, which is what "centred" means.
			local four = Scene.rowLayout(spot, facing, 4, LIVE)
			local middle = (four[2].Position + four[3].Position) / 2
			expect((middle - spot).Magnitude < 1e-3).to.equal(true)
		end)

		it("splits a bag of twelve into two rows, the second one behind the first", function()
			local row = Scene.rowLayout(spot, facing, 12, LIVE)
			expect(#row).to.equal(12)
			local look = Vector3.new(facing.X, 0, facing.Z).Unit
			local side = Scene.sideAxis(facing)
			local depth = LIVE.SCENE.ROW_SPACING_STUDS
			-- The first six are one row and the last six another, exactly `ROW_SPACING_STUDS` apart.
			local frontDepth = (row[1].Position - spot):Dot(look)
			local backDepth = (row[7].Position - spot):Dot(look)
			expect(math.abs(frontDepth - depth / 2) < 1e-3).to.equal(true)
			expect(math.abs(backDepth + depth / 2) < 1e-3).to.equal(true)
			for index = 1, 6 do
				expect(math.abs((row[index].Position - spot):Dot(look) - frontDepth) < 1e-3).to.equal(true)
				expect(math.abs((row[index + 6].Position - spot):Dot(look) - backDepth) < 1e-3).to.equal(true)
			end
			-- THE ROW IN FRONT IS THE ONE SHE SEES FIRST and it holds the first animals shot: index 1
			-- is further along the facing than index 7.
			expect(frontDepth > backDepth).to.equal(true)
			-- Nobody is laid on top of anybody: the nearest pair in the whole block is a spacing
			-- apart, which is what makes a bag of twelve walkable rather than a heap.
			local nearest = math.huge
			for a = 1, 12 do
				for b = a + 1, 12 do
					nearest = math.min(nearest, (row[a].Position - row[b].Position).Magnitude)
				end
			end
			expect(nearest > math.min(LIVE.SCENE.SPACING_STUDS, depth) - 1e-3).to.equal(true)
			-- A SHORT LAST ROW IS CENTRED ON ITS OWN WIDTH: seven animals is 6 + 1, and the 1 sits on
			-- the middle rather than hanging off the end.
			local seven = Scene.rowLayout(spot, facing, 7, LIVE)
			expect(math.abs((seven[7].Position - spot):Dot(side)) < 1e-3).to.equal(true)
		end)

		it("stands the people AROUND the animals, however big the bag is", function()
			-- A SMALL BAG DOES NOT MOVE THE RING: this is the scene Karen has already looked at.
			expect(Scene.ringRadiusFor(0, LIVE)).to.equal(LIVE.SCENE.RING_RADIUS_STUDS)
			expect(Scene.ringRadiusFor(3, LIVE)).to.equal(LIVE.SCENE.RING_RADIUS_STUDS)
			expect(Scene.cornerReachFor(3, LIVE)).to.equal(LIVE.SCENE.CORNER_STUDS)
			-- A BIG ONE DOES. Twelve animals reach 15 studs sideways and 4 deep, so a 14-stud ring
			-- would have put the people inside the row -- which is what this task found.
			local halfWidth, halfDepth = Scene.layoutExtent(12, LIVE)
			expect(math.abs(halfWidth - 15) < 1e-9).to.equal(true)
			expect(math.abs(halfDepth - 4) < 1e-9).to.equal(true)
			local radius = Scene.ringRadiusFor(12, LIVE)
			expect(radius > LIVE.SCENE.RING_RADIUS_STUDS).to.equal(true)
			-- EVERY ANIMAL IS INSIDE THE RING, and that is the claim, asserted animal by animal.
			local row = Scene.rowLayout(spot, facing, 12, LIVE)
			local ring = Scene.ringLayout(spot, 8, LIVE, 12)
			expect(#ring).to.equal(8)
			for _, at in ipairs(row) do
				local flat = Vector3.new(at.Position.X - spot.X, 0, at.Position.Z - spot.Z)
				expect(flat.Magnitude < radius).to.equal(true)
			end
			-- ...AND SO IS EVERY PERSON OUTSIDE IT, facing the middle, at the stand height.
			local centre = spot + Vector3.new(0, LIVE.STAND_HEIGHT_STUDS, 0)
			for _, at in ipairs(ring) do
				local flat = Vector3.new(at.Position.X - centre.X, 0, at.Position.Z - centre.Z)
				expect(math.abs(flat.Magnitude - radius) < 1e-3).to.equal(true)
				expect(at.LookVector:Dot((centre - at.Position).Unit) > 0.999).to.equal(true)
			end
			-- AND THE FOUR TORCHES ARE OUTSIDE THE PEOPLE.
			for _, corner in ipairs(Scene.cornerPositions(spot, facing, LIVE, 12)) do
				expect((corner - spot).Magnitude > radius).to.equal(true)
			end
			TestKit.note(
				string.format(
					"match_scene: 12 animals -> %d rows, half %.1f x %.1f, ring %.1f (was %.1f), corners %.1f",
					Scene.rowCount(12, LIVE),
					halfWidth,
					halfDepth,
					radius,
					LIVE.SCENE.RING_RADIUS_STUDS,
					Scene.cornerReachFor(12, LIVE)
				)
			)
		end)
	end)

	describe("the scene as Instances", function()
		local spot = Vector3.new(0, 10, -24)
		local facing = Vector3.new(0, 0, 1)

		afterEach(function()
			-- NOTHING OF THIS SPEC'S IS LEFT IN THE WORLD. The live drive builds its own scene at its
			-- own boundary (zz_drive_boundary.spec); a leftover folder from here would be a second
			-- scene nobody owns.
			Scene.clear()
		end)

		it("builds one folder with the animals it was given and four lamps, and takes it down whole", function()
			local kills = {
				{ kind = "male" },
				{ kind = "female" },
				{ kind = "cub" },
			}
			local laid = Scene.build(spot, facing, kills, CONFIG)
			expect(laid).to.equal(3)
			local folder = Scene.folder()
			expect(folder).to.be.ok()
			expect(folder.Parent).to.equal(Workspace)

			local lamps, bodies = 0, 0
			for _, child in ipairs(folder:GetChildren()) do
				if string.find(child.Name, Scene.LIGHT_PREFIX, 1, true) == 1 then
					lamps += 1
					-- A TORCH SINCE TASK 168: the post carries a `Flame` and the flame carries the
					-- fire and the light. The lamp moved off the post deliberately -- a `PointLight`
					-- shines from its own parent's position, so on a 10-stud post it was lighting
					-- the bodies from the post's middle.
					local flame = child:FindFirstChild(Scene.FLAME_NAME)
					expect(flame).to.be.ok()
					expect(flame:FindFirstChildOfClass("PointLight")).to.be.ok()
					expect(flame:FindFirstChildOfClass("PointLight").Brightness).to.equal(CONFIG.SCENE.LIGHT_BRIGHTNESS)
					expect(flame:FindFirstChildOfClass("Fire")).to.be.ok()
				elseif string.find(child.Name, Scene.ANIMAL_PREFIX, 1, true) == 1 then
					bodies += 1
					-- IT CANNOT STOP A PELLET, which is the one property here that is not tidiness:
					-- what a shot hit is what the safety rule and the hit record read.
					expect(child.CanQuery).to.equal(false)
					expect(child.CanCollide).to.equal(false)
					expect(child.Anchored).to.equal(true)
					-- ON the ground, not in it: the box sits on the spot's own y.
					expect(math.abs((child.Position.Y - child.Size.Y / 2) - spot.Y) < 1e-3).to.equal(true)
				end
			end
			expect(lamps).to.equal(4)
			expect(bodies).to.equal(3)
			expect(folder:FindFirstChild("Animal1"):GetAttribute("Kind")).to.equal("male")
			expect(folder:FindFirstChild("Animal3"):GetAttribute("Kind")).to.equal("cub")

			expect(Scene.clear()).to.equal(true)
			expect(Scene.folder()).to.equal(nil)
			expect(Scene.clear()).to.equal(false) -- nothing to take down twice
			TestKit.note(
				string.format(
					"match_scene: built=%d cleared=%d lamps=%d animals=%d",
					Scene.stats().built,
					Scene.stats().cleared,
					Scene.stats().lights,
					Scene.stats().animals
				)
			)
		end)

		it("rebuilds rather than adds, and caps a long drive's row", function()
			Scene.build(spot, facing, { { kind = "male" } }, CONFIG)
			local first = Scene.folder()
			expect(#first:GetChildren()).to.equal(5) -- one animal, four lamps
			-- A SECOND DRIVE'S SCENE REPLACES THE FIRST: the folder is destroyed and rebuilt, so two
			-- drives can never leave eight lamps standing.
			local many = {}
			for _ = 1, CONFIG.SCENE.MAX_ANIMALS + 3 do
				table.insert(many, { kind = "male" })
			end
			local laid = Scene.build(spot, facing, many, CONFIG)
			expect(laid).to.equal(CONFIG.SCENE.MAX_ANIMALS)
			expect(first.Parent).to.equal(nil) -- the first folder really went
			expect(#Scene.folder():GetChildren()).to.equal(CONFIG.SCENE.MAX_ANIMALS + 4)
		end)

		it("burns a real fire on each of the four corners, at the top of the post", function()
			-- KAREN, 2026-10-12 ~21:45: *"torches 4 in corners"*, and the Director: *"real torches: a
			-- post with a FIRE ... warm flicker"*. The FLICKER is `Fire`'s own -- it is a particle
			-- that animates itself -- which is why nothing in this repo writes a light per frame.
			Scene.build(spot, facing, { { kind = "male" } }, CONFIG)
			local folder = Scene.folder()
			local fires = 0
			for index = 1, 4 do
				local post = folder:FindFirstChild(string.format("%s%d", Scene.LIGHT_PREFIX, index))
				expect(post).to.be.ok()
				local flame = post:FindFirstChild(Scene.FLAME_NAME)
				expect(flame).to.be.ok()
				-- AT THE TOP OF THE POST, to the stud: the post is centred at half its height, so
				-- its top face is one half-height above that and the flame sits on it.
				expect(math.abs(flame.Position.Y - (post.Position.Y + CONFIG.SCENE.POST_SIZE.Y / 2)) < 1e-3).to.equal(
					true
				)
				-- IT CANNOT STOP A PELLET either, which is the one property in this folder that is
				-- not tidiness.
				expect(flame.CanQuery).to.equal(false)
				expect(flame.CanCollide).to.equal(false)
				local fire = flame:FindFirstChildOfClass("Fire")
				expect(fire).to.be.ok()
				expect(fire.Size).to.equal(CONFIG.SCENE.FIRE_SIZE)
				expect(fire.Heat).to.equal(CONFIG.SCENE.FIRE_HEAT)
				expect(fire.Enabled).to.equal(true)
				local light = flame:FindFirstChildOfClass("PointLight")
				expect(light.Range).to.equal(CONFIG.SCENE.LIGHT_RANGE_STUDS)
				-- SHADOWS STAY OFF: four shadow maps for a 25-second scene is the one cost number
				-- in this module.
				expect(light.Shadows).to.equal(false)
				fires += 1
			end
			expect(fires).to.equal(4)
			-- THE LIGHT REACHES THE ANIMALS from where it now hangs, which is the point of moving it:
			-- the corner's distance plus the post's height is inside the lamp's range.
			local corner = Scene.cornerPositions(spot, facing, CONFIG, 1)[1]
			local reach = (Vector3.new(corner.X, corner.Y + CONFIG.SCENE.POST_SIZE.Y, corner.Z) - spot).Magnitude
			expect(reach < CONFIG.SCENE.LIGHT_RANGE_STUDS).to.equal(true)
		end)

		it("builds an empty scene for a drive that shot nothing: the lights still go up", function()
			-- A blank drive is still a drive, and Karen still gets the gathering and the results
			-- table. Nothing to lay out is not nothing to show.
			expect(Scene.build(spot, facing, {}, CONFIG)).to.equal(0)
			expect(#Scene.folder():GetChildren()).to.equal(4)
		end)
	end)
	describe("the REAL animals in the rows (task 173)", function()
		-- KAREN, 2026-10-13 ~09:30, verbatim: *"and after hunt over we need to see boars shooted not
		-- boxes when we stand around"*.
		--
		-- THE SEAM IS ALL THIS SPEC NEEDS, and that is the point of it being a seam: `displayFor` is
		-- `function(kind, groundCFrame) -> Instance?`, so what `Match.Scene` does with a real animal
		-- is provable with a Model this file makes out of one Part -- no asset, no boar, no network.
		-- What the ANIMAL looks like and how it lies is `boar_model.spec`'s ("the display animal at
		-- the gathering lies dead on its side"), because `Boar.Body` owns it.
		local spot = Vector3.new(0, 10, -24)
		local facing = Vector3.new(0, 0, 1)

		afterEach(function()
			Scene.clear()
		end)

		-- A display source that records every ask, and refuses the kinds it is told to refuse -- which
		-- is how the per-animal fallback is driven.
		local function recorder(refuse: { [string]: boolean }?)
			local asks = {}
			local function displayFor(kind: string?, ground: CFrame): Instance?
				table.insert(asks, { kind = kind, ground = ground })
				if refuse and refuse[kind or ""] then
					return nil
				end
				local model = Instance.new("Model")
				local part = Instance.new("Part")
				part.Name = "FakeAnimal"
				part.Size = Vector3.new(1, 1, 4)
				part.Anchored = true
				part.CFrame = ground
				part.Parent = model
				model.PrimaryPart = part
				return model
			end
			return displayFor, asks
		end

		it("lays one real animal per shot animal, with its kind, where the row put it", function()
			local kills = { { kind = "male" }, { kind = "female" }, { kind = "cub" } }
			local displayFor, asks = recorder()
			local laid = Scene.build(spot, facing, kills, CONFIG, displayFor)
			expect(laid).to.equal(3)
			local folder = Scene.folder()

			-- ONE ASK PER ANIMAL, in the order they were shot, and with the kind the drive recorded.
			expect(#asks).to.equal(3)
			expect(asks[1].kind).to.equal("male")
			expect(asks[3].kind).to.equal("cub")

			-- ...AND THE CFRAME IS THE ROW'S OWN, to the stud: the scene decides where an animal lies
			-- and hands that in, so a display can never be laid out by two different rules.
			local row = Scene.rowLayout(spot, facing, 3, CONFIG)
			for index = 1, 3 do
				expect((asks[index].ground.Position - row[index].Position).Magnitude < 1e-3).to.equal(true)
				-- ON THE GROUND, which is what a thing that lies down needs to be told: the frame's
				-- own y is the spot's, with no half-height in it (that is the animal's business).
				expect(math.abs(asks[index].ground.Position.Y - spot.Y) < 1e-3).to.equal(true)
			end

			-- EVERY ONE OF THEM IS IN THE FOLDER, named as the box was, with the same two facts on it.
			local models = 0
			for index = 1, 3 do
				local child = folder:FindFirstChild(string.format("%s%d", Scene.ANIMAL_PREFIX, index))
				expect(child).to.be.ok()
				expect(child:IsA("Model")).to.equal(true)
				expect(child:GetAttribute("Kind")).to.equal(kills[index].kind)
				-- WHETHER IT IS THE REAL ANIMAL, on the thing itself: one attribute is the difference
				-- between "the asset did not load" and "the scene is wrong", and a live probe can
				-- count it without knowing what a boar model looks like.
				expect(child:GetAttribute("Model")).to.equal(true)
				models += 1
			end
			expect(models).to.equal(3)
			-- ...and the four torches are still four torches. Nothing else about the scene moved.
			expect(#folder:GetChildren()).to.equal(7)
			-- THE BREAKDOWN IS THIS SCENE'S AND IT ADDS UP (round 1, finding 1).
			expect(Scene.stats().models).to.equal(3)
			expect(Scene.stats().boxes).to.equal(0)
			expect(Scene.stats().models + Scene.stats().boxes).to.equal(laid)
		end)

		it("counts the models and the boxes of THIS scene, not of every scene since the server started", function()
			-- ROUND 1, FINDING 1, and it is the line Karen's own console prints: the owner says
			-- "gathered N animal(s) in R row(s): M real model(s), B box(es)" in ONE sentence, with
			-- `laid` from this build. Module-scope counters that were never reset made the second
			-- drive of a session print "gathered 2 animal(s) ... 4 real model(s)", and killed the
			-- breakdown's whole purpose with it: `models = 0` means the asset never arrived, and a
			-- session total can never go back to 0 once anything has loaded.
			--
			-- TWO BUILDS, WHICH IS WHAT A SECOND DRIVE IS. The old code fails the second block.
			local displayFor = recorder()
			local first = Scene.build(spot, facing, { { kind = "male" }, { kind = "female" } }, CONFIG, displayFor)
			expect(first).to.equal(2)
			expect(Scene.stats().models).to.equal(2)
			expect(Scene.stats().boxes).to.equal(0)

			-- A SECOND DRIVE: one real animal and one that could not be drawn.
			local mixed = recorder({ cub = true })
			local second = Scene.build(spot, facing, { { kind = "male" }, { kind = "cub" } }, CONFIG, mixed)
			expect(second).to.equal(2)
			expect(Scene.stats().models).to.equal(1) -- 3 before this fix
			expect(Scene.stats().boxes).to.equal(1)
			expect(Scene.stats().models + Scene.stats().boxes).to.equal(second)

			-- ...AND A THIRD THAT CAN DRAW NOTHING READS AS NOTHING DRAWN, which is the state the
			-- breakdown exists to report: the asset never arrived.
			local third = Scene.build(spot, facing, { { kind = "male" } }, CONFIG, nil)
			expect(Scene.stats().models).to.equal(0)
			expect(Scene.stats().boxes).to.equal(third)

			-- A DRIVE THAT SHOT NOTHING IS 0 AND 0, which is also true.
			Scene.build(spot, facing, {}, CONFIG, displayFor)
			expect(Scene.stats().models).to.equal(0)
			expect(Scene.stats().boxes).to.equal(0)
			-- `built` and `cleared` are NOT in that sentence and stay session counters.
			expect(Scene.stats().built >= 4).to.equal(true)
		end)

		it("faces every animal in the row the same way, which is the scene's own facing", function()
			-- A row reads as a row because they all lie the same way round (the tradition's rule as
			-- well: one species to a row, every animal on the same side).
			local kills = {}
			for _ = 1, 4 do
				table.insert(kills, { kind = "male" })
			end
			local displayFor, asks = recorder()
			Scene.build(spot, facing, kills, CONFIG, displayFor)
			expect(#asks).to.equal(4)
			local first = asks[1].ground.LookVector
			for index = 2, 4 do
				expect((asks[index].ground.LookVector - first).Magnitude < 1e-4).to.equal(true)
			end
			-- ...AND IT IS THE FACING THE SCENE WAS GIVEN, flat: the drive line's normal, which points
			-- up the drive at the beaters.
			expect((first - facing.Unit).Magnitude < 1e-4).to.equal(true)
		end)

		it("keeps the grey box for an animal it cannot draw, one animal at a time", function()
			-- THE FALLBACK IS PER ANIMAL AND NOT PER SCENE: a drive that shot a male and a cub, with
			-- only the male's asset published, lays out one model and one box. A mixed row is the
			-- honest row, and this is the state every world is in before its assets load.
			local kills = { { kind = "male" }, { kind = "cub" } }
			local displayFor = recorder({ cub = true })
			Scene.build(spot, facing, kills, CONFIG, displayFor)
			local folder = Scene.folder()
			local male = folder:FindFirstChild("Animal1")
			local cub = folder:FindFirstChild("Animal2")
			expect(male:IsA("Model")).to.equal(true)
			expect(male:GetAttribute("Model")).to.equal(true)
			-- THE BOX, UNCHANGED FROM TASK 159: a Part, at the kind's own size, on the ground, and
			-- unable to stop a pellet.
			expect(cub:IsA("Part")).to.equal(true)
			expect(cub:GetAttribute("Model")).to.equal(false)
			expect(cub:GetAttribute("Kind")).to.equal("cub")
			expect((cub.Size - Scene.animalSize("cub", CONFIG)).Magnitude < 1e-3).to.equal(true)
			expect(math.abs((cub.Position.Y - cub.Size.Y / 2) - spot.Y) < 1e-3).to.equal(true)
			expect(cub.CanQuery).to.equal(false)
			expect(cub.Anchored).to.equal(true)

			-- NO SOURCE AT ALL is the same answer for every animal, which is what every case above
			-- this describe has been asserting since task 159 -- and the DEV quick test's own state.
			Scene.build(spot, facing, kills, CONFIG, nil)
			expect(Scene.folder():FindFirstChild("Animal1"):IsA("Part")).to.equal(true)
			expect(Scene.folder():FindFirstChild("Animal1"):GetAttribute("Model")).to.equal(false)
		end)

		it("takes the real animals down with the scene, and rebuilds rather than adds", function()
			-- A DISPLAY IS THE SCENE'S OWN OBJECT: it arrives unparented, the scene parents it, and
			-- the scene destroys it with its folder. Nothing of one drive's bag may be standing when
			-- the next drive is counted in.
			local displayFor = recorder()
			Scene.build(spot, facing, { { kind = "male" }, { kind = "female" } }, CONFIG, displayFor)
			local first = Scene.folder()
			local kept = first:FindFirstChild("Animal1")
			expect(kept).to.be.ok()
			expect(#first:GetChildren()).to.equal(6) -- two animals, four torches

			-- A SECOND DRIVE REPLACES THE FIRST, whole.
			Scene.build(spot, facing, { { kind = "cub" } }, CONFIG, displayFor)
			expect(first.Parent).to.equal(nil)
			expect(kept.Parent).to.equal(nil) -- the real animal went with the folder
			expect(#Scene.folder():GetChildren()).to.equal(5)

			-- ...and taking the scene down takes them all.
			local second = Scene.folder():FindFirstChild("Animal1")
			expect(Scene.clear()).to.equal(true)
			expect(second.Parent).to.equal(nil)
			expect(Scene.folder()).to.equal(nil)
			TestKit.note(
				string.format(
					"match_scene: last build models=%d boxes=%d; session animals=%d",
					Scene.stats().models,
					Scene.stats().boxes,
					Scene.stats().animals
				)
			)
		end)

		it("still caps a long drive's bag, and asks for no more animals than it lays out", function()
			-- The cap is task 159's and is untouched: a long drive lays out `MAX_ANIMALS` and no
			-- display is built for the ones it does not lay out -- which is also the one thing that
			-- bounds the cost of this task (an ask is a Clone of a skinned mesh).
			local many = {}
			for _ = 1, CONFIG.SCENE.MAX_ANIMALS + 5 do
				table.insert(many, { kind = "male" })
			end
			local displayFor, asks = recorder()
			local laid = Scene.build(spot, facing, many, CONFIG, displayFor)
			expect(laid).to.equal(CONFIG.SCENE.MAX_ANIMALS)
			expect(#asks).to.equal(CONFIG.SCENE.MAX_ANIMALS)
		end)
	end)
end
