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
		RING_RADIUS_STUDS = 14,
		CORNER_STUDS = 16,
		ANIMAL_SIZE = Vector3.new(1.6, 1.4, 4.0),
		ANIMAL_SCALES = { male = 1.0, female = 0.85, cub = 0.45 },
		ANIMAL_COLOR = Color3.fromRGB(58, 48, 42),
		POST_SIZE = Vector3.new(0.6, 10, 0.6),
		POST_COLOR = Color3.fromRGB(70, 60, 50),
		LIGHT_COLOR = Color3.fromRGB(255, 190, 120),
		LIGHT_BRIGHTNESS = 4,
		LIGHT_RANGE_STUDS = 60,
	},
}

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
					expect(child:FindFirstChildOfClass("PointLight")).to.be.ok()
					expect(child:FindFirstChildOfClass("PointLight").Brightness).to.equal(CONFIG.SCENE.LIGHT_BRIGHTNESS)
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

		it("builds an empty scene for a drive that shot nothing: the lights still go up", function()
			-- A blank drive is still a drive, and Karen still gets the gathering and the results
			-- table. Nothing to lay out is not nothing to show.
			expect(Scene.build(spot, facing, {}, CONFIG)).to.equal(0)
			expect(#Scene.folder():GetChildren()).to.equal(4)
		end)
	end)
end
