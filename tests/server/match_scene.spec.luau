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
		-- THERE IS DELIBERATELY NO `KIND_ORDER` HERE (task 255, round 1 note). With the key absent
		-- `Scene.ordered` ranks every kind the same and breaks the tie on the shot index, so it is
		-- the IDENTITY -- which is what keeps every case written before task 255 asking what it
		-- asked, the task-173 `displayFor` case ("ONE ASK PER ANIMAL, in the order they were shot")
		-- among them. The one case that is ABOUT the ordering builds its own config with a
		-- `KIND_ORDER` in it rather than changing this one.
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

		-- ---------------- WHERE A BEATER WHO IS THROUGH WAITS (task 261, item 2)
		--
		-- KAREN, 2026-10-25: *"I reach out first and then can go around hunters and spook all animals
		-- in there position and need to wait until all beaters cross or time pass, we need better
		-- solution here"*.
		it("puts a beater who is through BEHIND the hunters, in a centred row (task 261)", function()
			local behind = CONFIG.BEATER_THROUGH.BEHIND_STUDS
			local spacing = CONFIG.BEATER_THROUGH.SPACING_STUDS
			local first = Match.throughSpotFor({ posts = POSTS, line = LINE }, CONFIG, 0)
			expect(first).to.be.ok()
			local at = (first :: CFrame).Position
			-- THE FIRST MAN THROUGH STANDS EXACTLY BEHIND THE MIDDLE STAND (x = 0 of three)...
			expect(at.X).to.equal(0)
			-- ...ON THE HUNTERS' OWN SIDE OF THE LINE, which is the side the normal does NOT point
			-- at, and WELL BACK: `BEATER_CROSS_MARGIN_STUDS` is 10, so a man who has just crossed is
			-- 10 studs past the stand and this is 30 further still.
			expect(at.Z).to.equal(-behind)
			expect(behind > CONFIG.BEATER_CROSS_MARGIN_STUDS * 2).to.equal(true)
			-- THE GROUND IS THE POST'S OWN UNDERSIDE, `gatherSpotFor`'s rule and its reason.
			expect(at.Y).to.equal(10)
			-- ...AND HE LOOKS BACK UP THE DRIVE HE HAS JUST FINISHED, not into the empty wood.
			expect((first :: CFrame).LookVector.Z).to.be.near(1, 1e-4)
			-- THE ROW GROWS OUTWARDS FROM THE MIDDLE, so it is centred at every size and no two men
			-- stand in the same place.
			local second = Match.throughSpotFor({ posts = POSTS, line = LINE }, CONFIG, 1)
			local third = Match.throughSpotFor({ posts = POSTS, line = LINE }, CONFIG, 2)
			expect((second :: CFrame).Position.X).to.equal(spacing)
			expect((third :: CFrame).Position.X).to.equal(-spacing)
			expect((second :: CFrame).Position.Z).to.equal(-behind)
			-- ...AND IT IS NEVER THE WORLD'S GATHERING SPOT, which is the lobby yard in the Forest
			-- Test: moving a beater there mid-drive would take him out of the hunt he is still in.
			local gathered = Match.gatherSpotOf(function()
				return Vector3.new(900, 150, 900), Vector3.new(0, 0, 1)
			end, { posts = POSTS, line = LINE }, CONFIG)
			expect((gathered :: Vector3).X).to.equal(900)
			expect(at.X).never.to.equal(900)
		end)

		it("has nowhere to put a beater who is through with no stands at all", function()
			expect((Match.throughSpotFor({ posts = {}, line = LINE }, CONFIG, 0))).to.equal(nil)
			expect((Match.throughSpotFor(nil, CONFIG, 0))).to.equal(nil)
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

	-- ------------------------------------------------- THE BAG OF 20+, IN TIDY ROWS (task 255)
	--
	-- KAREN, 2026-10-24, verbatim: *"also when there is a lot animals killed on end of game we need
	-- gather them in several rows"*.
	describe("a bigger bag is laid out in tidy rows, by species then size (task 255)", function()
		local spot = Vector3.new(0, 10, -24)
		local facing = Vector3.new(0, 0, 1)

		-- HOW WIDE AND HOW LONG EACH KIND REALLY IS WHEN IT IS LYING DOWN, in studs. MEASURED off
		-- the LOADED meshes in a live Play session of the Forest Test on 2026-10-24 --
		-- `MeshPart.Size` read back off each animal's own `Visual`, plus the published stag model --
		-- and NOT taken from `ANIMAL_SIZE`, which is the grey-box fallback and is a third of the
		-- real thing.
		--
		-- `Body.lyingCFrame` rolls a display by `DISPLAY_ROLL_DEG` about its LONG axis, which stands
		-- the mesh's X up and lays its Y ACROSS the row. So `across` is the mesh's Y and `along` is
		-- its Z, and the pile Karen saw is one subtraction away: a rolled stag is 7.9202 across and
		-- the spacing was 6.
		--
		-- IT IS DATA IN THIS FILE AND NOT IN `Match.CONFIG`, deliberately: the scene must not learn
		-- what a boar is (`Scene`'s own header), and what these cases assert is that the two
		-- spacings in that config CLEAR these numbers. A retune that re-creates the pile fails here.
		local MEASURED = {
			{ kind = "boar male", across = 3.2573, along = 5.5 },
			{ kind = "boar female", across = 2.6473, along = 4.675 },
			{ kind = "boar cub", across = 1.439, along = 2.475 },
			-- THE LEGENDARY IS THE MALE'S MESH AT 1.35 (`Boar.CONFIG.KINDS`), which is the longest
			-- thing in the game: 7.425 nose to tail.
			{ kind = "boar legendary", across = 3.2573 * 1.35, along = 5.5 * 1.35 },
			-- THE STAG IS THE WIDEST, and by a long way -- a red deer is a leggier, TALLER animal,
			-- so rolled it is nearly square where a boar is not.
			{ kind = "stag", across = 7.9202, along = 7.05 },
			-- The hind and the calf are the stag's mesh at 6.03/7.05 and 3.49/7.05 of its length
			-- (`Match.CONFIG.SCENE.ANIMAL_SCALES`' own arithmetic).
			{ kind = "hind", across = 7.9202 * (6.03 / 7.05), along = 6.03 },
			{ kind = "calf", across = 7.9202 * (3.49 / 7.05), along = 3.49 },
		}

		it("spaces the rows wide enough that the biggest animal in the game cannot overlap", function()
			local widest, widestKind = 0, ""
			local longest, longestKind = 0, ""
			for _, row in ipairs(MEASURED) do
				if row.across > widest then
					widest, widestKind = row.across, row.kind
				end
				if row.along > longest then
					longest, longestKind = row.along, row.kind
				end
			end
			-- The measurement itself: the stag is the widest and the legendary boar the longest.
			expect(widestKind).to.equal("stag")
			expect(longestKind).to.equal("boar legendary")
			expect(math.abs(widest - 7.9202) < 1e-4).to.equal(true)
			expect(math.abs(longest - 7.425) < 1e-4).to.equal(true)

			-- THE DEFECT, STATED AS ARITHMETIC: at the old 6 two stags overlapped by 1.9202 studs.
			expect(math.abs((widest - 6) - 1.9202) < 1e-4).to.equal(true)

			-- ...AND THE SHIPPED NUMBERS CLEAR IT, on both axes, for every kind.
			expect(LIVE.SCENE.SPACING_STUDS >= widest).to.equal(true)
			expect(LIVE.SCENE.ROW_SPACING_STUDS >= longest).to.equal(true)
			for _, row in ipairs(MEASURED) do
				expect(LIVE.SCENE.SPACING_STUDS > row.across).to.equal(true)
				expect(LIVE.SCENE.ROW_SPACING_STUDS > row.along).to.equal(true)
			end
		end)

		it("lays the whole cap out in four rows, and nobody touches anybody", function()
			-- MORE THAN THE TWELVE SHE HAS BEEN SEEING, and a whole number of rows so the block is
			-- never a row of one. The cap is 16 and not the Director's 20+ because the lobby's
			-- gathering yard will not hold 20 -- `MAX_ANIMALS`' own comment has that arithmetic and
			-- `ESCALATE.md` carries the decision.
			expect(LIVE.SCENE.MAX_ANIMALS > 12).to.equal(true)
			expect(LIVE.SCENE.MAX_ANIMALS % Scene.perRow(LIVE)).to.equal(0)
			expect(Scene.rowCount(LIVE.SCENE.MAX_ANIMALS, LIVE)).to.equal(4)
			expect(Scene.rowCount(13, LIVE)).to.equal(4)

			-- THE WHOLE BLOCK, AT THE CAP, PAIR BY PAIR. The nearest two animals in the biggest bag
			-- this game lays out are a spacing apart, and that spacing clears the widest animal --
			-- so the worst case is two stags side by side with a stud of grass between them.
			local count = LIVE.SCENE.MAX_ANIMALS
			local row = Scene.rowLayout(spot, facing, count, LIVE)
			expect(#row).to.equal(count)
			local nearest = math.huge
			for a = 1, count do
				for b = a + 1, count do
					nearest = math.min(nearest, (row[a].Position - row[b].Position).Magnitude)
				end
			end
			local tightest = math.min(LIVE.SCENE.SPACING_STUDS, LIVE.SCENE.ROW_SPACING_STUDS)
			expect(nearest > tightest - 1e-3).to.equal(true)
			expect(nearest > 7.9202).to.equal(true)

			-- ...AND THE BLOCK IS SQUARE AND NOT A HEDGE, which is the cap's original purpose: the
			-- whole bag in ONE line would have been 135 studs of front.
			local halfWidth, halfDepth = Scene.layoutExtent(count, LIVE)
			expect(math.abs(halfWidth - halfDepth) < 1e-6).to.equal(true)
			expect(halfWidth * 2 < (count - 1) * LIVE.SCENE.SPACING_STUDS).to.equal(true)

			-- THE BLOCK HAS TO STAND IN KAREN'S YARD, and that is the whole reason the cap is 16:
			-- `lobby.spec` asserts the containment against the real pad, and this is the bound it
			-- comes down to. 28 is half the `Gather` pad's measured 56, and the lodge's chimney is
			-- 29.0 studs from the gathering's centre (both read off the live lobby, 2026-10-24).
			expect(Scene.cornerReachFor(count, LIVE) < 28).to.equal(true)
			-- ...and one more animal to a row would not fit, which is what makes 4 the answer rather
			-- than a preference.
			local wider = table.clone(LIVE.SCENE)
			wider.PER_ROW = 5
			expect(Scene.cornerReachFor(20, { SCENE = wider }) > 29).to.equal(true)
		end)

		it("orders the bag by species then size, stably, and leaves an unknown kind at the back", function()
			-- SHOT ORDER IN, TIDY ORDER OUT. A calf first, a stag third -- and the answer is the
			-- boars (biggest first) then the red deer (biggest first).
			local shot = {
				{ kind = "calf", at = 1 },
				{ kind = "cub", at = 2 },
				{ kind = "stag", at = 3 },
				{ kind = "male", at = 4 },
				{ kind = "hind", at = 5 },
				{ kind = "legendary", at = 6 },
			}
			local tidy = Scene.ordered(shot, LIVE)
			local kinds = {}
			for _, kill in ipairs(tidy) do
				table.insert(kinds, kill.kind)
			end
			expect(table.concat(kinds, ",")).to.equal("legendary,male,cub,stag,hind,calf")

			-- THE DRIVE'S OWN RECORD IS NOT TOUCHED: `Match` keeps reading it for the score and the
			-- report, so a layout that reordered it in place would reorder the results table too.
			expect(shot[1].kind).to.equal("calf")
			expect(#shot).to.equal(6)

			-- STABLE INSIDE ONE KIND, which `table.sort` is NOT (the engine's own docs say the order
			-- of equal elements is undefined): three males come out in the order she shot them.
			local males = Scene.ordered({
				{ kind = "male", at = 11 },
				{ kind = "stag", at = 12 },
				{ kind = "male", at = 13 },
				{ kind = "male", at = 14 },
			}, LIVE)
			expect(males[1].at).to.equal(11)
			expect(males[2].at).to.equal(13)
			expect(males[3].at).to.equal(14)
			expect(males[4].kind).to.equal("stag")

			-- A KIND NOBODY HAS HEARD OF GOES TO THE BACK, TOGETHER, in shot order -- so a species
			-- added later is laid out honestly before anybody remembers `KIND_ORDER`.
			local future = Scene.ordered({
				{ kind = "roebuck", at = 1 },
				{ kind = "male", at = 2 },
				{ kind = "fox", at = 3 },
			}, LIVE)
			expect(future[1].kind).to.equal("male")
			expect(future[2].kind).to.equal("roebuck")
			expect(future[3].kind).to.equal("fox")

			-- ...AND EVERY SHIPPED KIND IS IN THE LIST, so none of them is silently sorted to the
			-- back of the bag. `ANIMAL_SCALES` is the roll of kinds this scene can draw.
			local ranked = {}
			for _, kind in ipairs(LIVE.SCENE.KIND_ORDER) do
				ranked[kind] = true
			end
			local checked = 0
			for kind in pairs(LIVE.SCENE.ANIMAL_SCALES) do
				checked += 1
				expect(ranked[kind]).to.equal(true)
			end
			expect(checked > 0).to.equal(true)
		end)

		it("sorts exactly the list it is handed, and reads nothing beyond it", function()
			-- `Scene.ordered` ALONE, on a bag twice the cap: it sorts what it is HANDED and nothing
			-- else, which is the contract `Scene.build` relies on when it hands over a slice.
			--
			-- IT IS NOT THE CASE THAT PROVES THE BUILD DROPS THE RIGHT ANIMALS -- round 1's finding
			-- 2 was that this case's old name claimed exactly that and asserted none of it. The
			-- build is driven, through its own folder, by *"drops the kills she shot LAST, never the
			-- ones she shot first"* below.
			local cap = LIVE.SCENE.MAX_ANIMALS
			local kills = {}
			for index = 1, cap do
				table.insert(kills, { kind = "male", at = index })
			end
			for index = cap + 1, cap * 2 do
				table.insert(kills, { kind = "calf", at = index })
			end
			expect(math.min(#kills, cap)).to.equal(cap)
			local tidy = Scene.ordered(kills, LIVE)
			-- EVERY kill it was handed comes back, none of them dropped, in rank order -- so this
			-- function has no cap in it and `Scene.build` is the only thing that drops anything.
			expect(#tidy).to.equal(#kills)
			expect(tidy[1].kind).to.equal("male")
			expect(tidy[cap].kind).to.equal("male")
			expect(tidy[cap + 1].kind).to.equal("calf")
			-- ...and handed the SLICE instead, it answers only the slice.
			local slice = table.move(kills, 1, cap, 1, {})
			local sliced = Scene.ordered(slice, LIVE)
			expect(#sliced).to.equal(cap)
			for _, kill in ipairs(sliced) do
				expect(kill.kind).to.equal("male")
			end
		end)
	end)

	describe("the animals in several rows (task 168)", function()
		local spot = Vector3.new(0, 10, -24)
		local facing = Vector3.new(0, 0, 1)

		-- KAREN, 2026-10-12 ~21:45: *"animals layed down in front in several lines if more"*.
		--
		-- EVERY CASE BELOW READS `Scene.perRow(LIVE)` AND `MAX_ANIMALS` RATHER THAN 6 AND 12, and
		-- that is task 255's doing rather than tidying: these cases are about the SHAPE of the block
		-- -- one row, then rows behind it, a short last row centred on its own width, the people
		-- outside all of it -- and they were written with the then-current numbers typed in, so the
		-- whole set failed when `PER_ROW` went 6 -> 4 and the cap 12 -> 16 for reasons that have
		-- nothing to do with what any of them asserts. `match_config.spec` is where the NUMBERS are
		-- pinned, and the task-255 block above is where the measurement that chose them lives.
		local PER = Scene.perRow(LIVE)
		local CAP = LIVE.SCENE.MAX_ANIMALS

		it("counts the rows a bag makes, and the cap is a whole number of them", function()
			expect(PER > 1).to.equal(true)
			expect(Scene.rowCount(0, LIVE)).to.equal(0)
			expect(Scene.rowCount(1, LIVE)).to.equal(1)
			expect(Scene.rowCount(PER - 1, LIVE)).to.equal(1)
			expect(Scene.rowCount(PER, LIVE)).to.equal(1)
			expect(Scene.rowCount(PER + 1, LIVE)).to.equal(2)
			expect(Scene.rowCount(2 * PER, LIVE)).to.equal(2)
			expect(Scene.rowCount(2 * PER + 1, LIVE)).to.equal(3)
			-- ...and the cap is a whole number of rows, so the block is never a row of one.
			expect(CAP % PER).to.equal(0)
		end)

		it("keeps one row exactly where it was, and centres every row on the spot", function()
			-- ONE ROW IS THE SCENE KAREN HAS ALREADY SEEN: a full row, `SPACING_STUDS` apart,
			-- centred, with no depth to spread into.
			local row = Scene.rowLayout(spot, facing, PER, LIVE)
			expect(#row).to.equal(PER)
			local side = Scene.sideAxis(facing)
			local middle = (PER + 1) / 2
			for index = 1, PER do
				local offset = row[index].Position - spot
				expect(math.abs(offset:Dot(Vector3.new(facing.X, 0, facing.Z).Unit)) < 1e-3).to.equal(true)
				expect(math.abs(offset:Dot(side) - (index - middle) * LIVE.SCENE.SPACING_STUDS) < 1e-3).to.equal(true)
			end
			-- ...AND AN EVEN ROW STRADDLES THE SPOT while an odd one has an animal ON it, which is
			-- what "centred on its own width" means in both parities.
			local even = Scene.rowLayout(spot, facing, 2, LIVE)
			expect(((even[1].Position + even[2].Position) / 2 - spot).Magnitude < 1e-3).to.equal(true)
			local odd = Scene.rowLayout(spot, facing, 3, LIVE)
			expect((odd[2].Position - spot).Magnitude < 1e-3).to.equal(true)
		end)

		it("splits a full cap into its rows, each one behind the last", function()
			local rows = Scene.rowCount(CAP, LIVE)
			expect(rows > 1).to.equal(true)
			local row = Scene.rowLayout(spot, facing, CAP, LIVE)
			expect(#row).to.equal(CAP)
			local look = Vector3.new(facing.X, 0, facing.Z).Unit
			local side = Scene.sideAxis(facing)
			local depth = LIVE.SCENE.ROW_SPACING_STUDS
			-- EVERY ROW IS ONE `ROW_SPACING_STUDS` BEHIND THE ONE IN FRONT OF IT, and every animal
			-- in a row shares that row's depth.
			local depths = {}
			for r = 1, rows do
				local first = (r - 1) * PER + 1
				depths[r] = (row[first].Position - spot):Dot(look)
				for index = first, math.min(first + PER - 1, CAP) do
					expect(math.abs((row[index].Position - spot):Dot(look) - depths[r]) < 1e-3).to.equal(true)
				end
			end
			for r = 2, rows do
				expect(math.abs((depths[r - 1] - depths[r]) - depth) < 1e-3).to.equal(true)
			end
			-- THE ROW IN FRONT IS THE ONE SHE SEES FIRST, and the whole block is centred in depth.
			expect(depths[1] > depths[rows]).to.equal(true)
			expect(math.abs(depths[1] - (rows - 1) * depth / 2) < 1e-3).to.equal(true)
			-- Nobody is laid on top of anybody: the nearest pair in the whole block is a spacing
			-- apart, which is what makes a full bag walkable rather than a heap.
			local nearest = math.huge
			for a = 1, CAP do
				for b = a + 1, CAP do
					nearest = math.min(nearest, (row[a].Position - row[b].Position).Magnitude)
				end
			end
			expect(nearest > math.min(LIVE.SCENE.SPACING_STUDS, depth) - 1e-3).to.equal(true)
			-- A SHORT LAST ROW IS CENTRED ON ITS OWN WIDTH: a full row plus one, and the one sits on
			-- the middle rather than hanging off the end.
			local plusOne = Scene.rowLayout(spot, facing, PER + 1, LIVE)
			expect(math.abs((plusOne[PER + 1].Position - spot):Dot(side)) < 1e-3).to.equal(true)
		end)

		it("stands the people AROUND the animals, however big the bag is", function()
			-- A SMALL BAG DOES NOT MOVE THE RING, and task 255 moved where "small" stops -- which is
			-- asserted as the BOUNDARY rather than at a number somebody picked. One row of `k`
			-- animals reaches `(k - 1) * SPACING / 2` sideways, so the floor holds while that plus
			-- `RING_MARGIN_STUDS` is under `RING_RADIUS_STUDS`: at `SPACING_STUDS` 9 that is k <= 2
			-- (4.5 + 6 = 10.5), where at the old 6 it was k <= 3. A bag of three now reaches 9 studs
			-- and the ring grows to 15 -- correctly, because that is the whole point of task 168's
			-- rule, and the animals it is making room for are three times as wide as they were.
			local floor = LIVE.SCENE.RING_RADIUS_STUDS
			expect(Scene.ringRadiusFor(0, LIVE)).to.equal(floor)
			expect(Scene.ringRadiusFor(1, LIVE)).to.equal(floor)
			expect(Scene.cornerReachFor(1, LIVE)).to.equal(LIVE.SCENE.CORNER_STUDS)
			local small = math.floor(2 * (floor - LIVE.SCENE.RING_MARGIN_STUDS) / LIVE.SCENE.SPACING_STUDS) + 1
			expect(small >= 1).to.equal(true)
			expect(Scene.ringRadiusFor(small, LIVE)).to.equal(floor)
			-- ...AND ONE MORE THAN THAT DOES MOVE IT, which is what makes the boundary a boundary and
			-- not a coincidence.
			expect(Scene.ringRadiusFor(small + 1, LIVE) > floor).to.equal(true)
			TestKit.note(
				string.format(
					"match_scene: the ring holds at %d studs up to %d animal(s); %d of them grows it to %.1f",
					floor,
					small,
					small + 1,
					Scene.ringRadiusFor(small + 1, LIVE)
				)
			)
			-- A BIG ONE DOES, and the extent is the arithmetic of the two spacings rather than two
			-- typed numbers: a full cap reaches `(PER - 1) * SPACING / 2` sideways and
			-- `(rows - 1) * ROW_SPACING / 2` deep, so a `RING_RADIUS_STUDS` ring would put the
			-- people inside the row -- which is what task 168 found.
			local rows = Scene.rowCount(CAP, LIVE)
			local halfWidth, halfDepth = Scene.layoutExtent(CAP, LIVE)
			expect(math.abs(halfWidth - (PER - 1) * LIVE.SCENE.SPACING_STUDS / 2) < 1e-9).to.equal(true)
			expect(math.abs(halfDepth - (rows - 1) * LIVE.SCENE.ROW_SPACING_STUDS / 2) < 1e-9).to.equal(true)
			local radius = Scene.ringRadiusFor(CAP, LIVE)
			expect(radius > LIVE.SCENE.RING_RADIUS_STUDS).to.equal(true)
			-- EVERY ANIMAL IS INSIDE THE RING, and that is the claim, asserted animal by animal.
			local row = Scene.rowLayout(spot, facing, CAP, LIVE)
			local ring = Scene.ringLayout(spot, 8, LIVE, CAP)
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
			for _, corner in ipairs(Scene.cornerPositions(spot, facing, LIVE, CAP)) do
				expect((corner - spot).Magnitude > radius).to.equal(true)
			end
			TestKit.note(
				string.format(
					"match_scene: %d animals -> %d rows, half %.1f x %.1f, ring %.1f (was %.1f), corners %.1f",
					CAP,
					rows,
					halfWidth,
					halfDepth,
					radius,
					LIVE.SCENE.RING_RADIUS_STUDS,
					Scene.cornerReachFor(CAP, LIVE)
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

		-- ------------------------------------------------- WHICH KILLS REACH THE GROUND (round 1,
		-- finding 2). The Reviewer's own words: *"the case that names this behaviour asserts nothing
		-- about it and passes with the order reversed; no case anywhere drives `Scene.build`'s
		-- ordering at all"*. Both halves were true and this is the case that was missing.
		--
		-- IT DRIVES `Scene.build` ITSELF and reads the `Kind` attribute off what landed in the
		-- folder, which is the only place "which animals did she actually see" is a fact. It needs a
		-- config with a `KIND_ORDER` -- this file's own `CONFIG` deliberately has none (see its
		-- declaration) -- so it builds one here rather than changing the config every other case in
		-- the file depends on.
		--
		-- IT FAILS ON ROUND 1'S CODE. That code sorted the WHOLE bag and then took the first
		-- `MAX_ANIMALS` of the SORTED list, so the four calves she shot first vanished and four
		-- males she shot AFTER the cap were laid out in their place. The assertion below is `calf`
		-- four times; round 1 answers `male` four times.
		it("drops the kills she shot LAST, never the ones she shot first, whatever species they are", function()
			local SPOT, FACING = Vector3.new(0, 10, -24), Vector3.new(0, 0, 1)
			local ordered = {
				STAND_HEIGHT_STUDS = CONFIG.STAND_HEIGHT_STUDS,
				BEATER_CROSS_MARGIN_STUDS = CONFIG.BEATER_CROSS_MARGIN_STUDS,
				SCENE = table.clone(CONFIG.SCENE),
			}
			-- The male OUTRANKS the calf, so a sort-then-cap would keep males and drop every calf.
			ordered.SCENE.KIND_ORDER = { "male", "calf" }
			local cap = ordered.SCENE.MAX_ANIMALS
			expect(cap >= 2).to.equal(true)

			-- THE BAG: every calf shot FIRST, then four times the cap in males.
			local kills = {}
			for _ = 1, cap do
				table.insert(kills, { kind = "calf" })
			end
			for _ = 1, cap * 4 do
				table.insert(kills, { kind = "male" })
			end

			local laid = Scene.build(SPOT, FACING, kills, ordered)
			expect(laid).to.equal(cap)
			local folder = Scene.folder()
			expect(folder).to.be.ok()
			local kinds = {}
			for index = 1, laid do
				local animal = (folder :: Folder):FindFirstChild(Scene.ANIMAL_PREFIX .. tostring(index))
				expect(animal).to.be.ok()
				table.insert(kinds, tostring((animal :: Instance):GetAttribute("Kind")))
			end
			-- EVERY ONE OF THEM IS A CALF: the cap is her first `cap` kills, and the tidying happens
			-- INSIDE that slice. One `male` here is finding 1 back.
			expect(#kinds).to.equal(cap)
			for _, kind in ipairs(kinds) do
				expect(kind).to.equal("calf")
			end

			-- ...AND THE TIDYING STILL HAPPENS INSIDE THE SLICE, which is the other half: the same
			-- cap, a mixed slice, and the males come out in front of the calves.
			local mixed = {}
			for index = 1, cap do
				table.insert(mixed, { kind = if index % 2 == 0 then "male" else "calf" })
			end
			for _ = 1, cap do
				table.insert(mixed, { kind = "male" })
			end
			expect(Scene.build(SPOT, FACING, mixed, ordered)).to.equal(cap)
			local after = Scene.folder()
			local tidied = {}
			for index = 1, cap do
				local animal = (after :: Folder):FindFirstChild(Scene.ANIMAL_PREFIX .. tostring(index))
				table.insert(tidied, tostring((animal :: Instance):GetAttribute("Kind")))
			end
			local males, calves = 0, 0
			for index, kind in ipairs(tidied) do
				if kind == "male" then
					males += 1
					-- every male is laid out before every calf
					expect(calves).to.equal(0)
					expect(index <= cap // 2).to.equal(true)
				else
					calves += 1
				end
			end
			-- The slice held half of each, so the picture is half and half -- NOT the `cap` males
			-- that a sort over the whole bag would have produced.
			expect(males).to.equal(cap // 2)
			expect(calves).to.equal(cap - cap // 2)
			TestKit.note(
				string.format(
					"match_scene: cap %d of %d kills -> %s (the slice is her first %d, tidied inside itself)",
					cap,
					#mixed,
					table.concat(tidied, ","),
					cap
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
