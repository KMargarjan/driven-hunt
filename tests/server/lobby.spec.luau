-- lobby.spec: THE LOBBY'S ARITHMETIC AND ITS GEOMETRY -- no world, no terrain, no player and no
-- clock. `Lobby.Join` and `Lobby.Field` are pure for exactly this reason: Karen's rule is *"step
-- into a marked spot by the truck"*, and "what happens when he steps out at 4.9 seconds" is a table
-- of cases a spec can state rather than a thing somebody watches in a playtest.
--
-- `Lobby.Build` IS DRIVEN INTO A FOLDER OF THIS SPEC'S OWN, which is what makes the part budget, the
-- collision set and *"no Script anywhere in the tree"* CHECKED claims rather than promises -- and
-- what lets this spec run safely in the DEV place, where there is no lobby at all.
--
-- `Field.fill` IS DRIVEN AGAINST A FAKE TERRAIN. That is not convenience: it is the reason `terrain`
-- is an argument at all, and it is what guarantees that no spec in the harness's own place can write
-- the DEV place's terrain, ever.
--
-- THE SWITCH-OFF CASE IS THE ONE THAT MATTERS MOST (CLAUDE.md "Feature flags"): `anchorFor("map:v1")`
-- is nil, which is what makes "off means today's game bit for bit" a checked claim -- `Lobby.start`
-- returns false on a nil anchor and builds nothing.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/lobby.md (section 16.1)
-- Note:   docs/research/2026-10-13-lobby-and-the-truck.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Data = require(ReplicatedStorage:WaitForChild("Lobby"))
local Lobby = require(ServerScriptService:WaitForChild("Lobby"))
-- THE OUTFIT OWNER, READ-ONLY AND ONLY TO ASK WHAT WORDS IT KNOWS (review round 1, finding 1). The
-- lobby does not require `Match`; this spec does, because *"the keeper is dressed"* is a claim about
-- what ANOTHER owner will do with the team this one hands it, and a spec that asserts the config
-- against itself passes for any string -- which is exactly how an undressed man got through round 1.
local Match = require(ServerScriptService:WaitForChild("Match"))
-- `TestKit.note` only, for the measured lines the gathering yard's audits print (task 191): a
-- clearance is worth more in the report as a NUMBER than as a passing assertion.
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Join = Lobby.Join
local Pads = Lobby.Pads
local Field = Lobby.Field
-- TASK 244: the ONE other system in this repository that calls `Terrain:ReplaceMaterial`, read here
-- only so the engine's voxel resolution is asserted to be ONE number named twice rather than two
-- numbers that happen to agree. The two owners do not -- and must not -- require each other.
local Ground = require(ServerScriptService:WaitForChild("Places"):WaitForChild("Ground"))
local Build = Lobby.Build

local CFG = Data.CONFIG

-- A TERRAIN THAT RECORDS AND WRITES NOTHING. TWO methods since task 244, because `Field.fill` calls
-- exactly two: the blocks, and the scrub that follows the air cut.
local function fakeTerrain()
	local calls = {}
	-- TASK 244: the fake answers the WHOLE contract, `ReplaceMaterial` included. `Field.fill` calls
	-- it unguarded for the reason it calls `FillBlock` unguarded -- `terrain` is injected so that no
	-- spec can write the DEV place's terrain, not so a stand-in may answer half of it.
	local replacements = {}
	return {
		calls = calls,
		replacements = replacements,
		FillBlock = function(_self, at: CFrame, size: Vector3, material: Enum.Material)
			table.insert(calls, { at = at, size = size, material = material })
		end,
		ReplaceMaterial = function(_self, region: Region3, resolution: number, from: Enum.Material, to: Enum.Material)
			table.insert(replacements, { region = region, resolution = resolution, from = from, to = to })
		end,
	}
end

-- A FOLDER OF FAKE FREE MODELS (task 180). Plain parts in a Model, one per template name, so the
-- free-model branch is reachable WITHOUT a Creator Store round trip and without the Forest Test
-- place -- which is the whole point of `templates` being an argument. `withScript` plants a Script
-- inside the truck, because "a free model is the classic place to hide one" is only a checked claim
-- if a spec actually hides one.
--
-- SINCE TASK 187 THERE IS NO LODGE AND NO TROPHY HEAD HERE, because there is no template for either
-- any more: Karen judged the free cabins *"garbadge"* and the house, its windows, its fire and every
-- antler on its walls are built from parts by this repository. What is still a free model is the
-- truck and the trees.
local function fakeTemplates(withScript: boolean?): Instance
	local folder = Instance.new("Folder")
	folder.Name = Data.TEMPLATES_NAME
	local function model(name: string, size: Vector3): Model
		local made = Instance.new("Model")
		made.Name = name
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Size = size
		body.Anchored = false -- the clone must anchor it: a free model ships with whatever it ships
		body.Parent = made
		made.Parent = folder
		return made
	end
	local lorry = model(Data.TEMPLATE.TRUCK, Vector3.new(18, 7, 9))
	local trees = Instance.new("Folder")
	trees.Name = Data.TEMPLATE.TREES
	trees.Parent = folder
	-- THE SPECIES THE ALLOW-LIST ACTUALLY ASKS FOR (task 196 part 3c). `treeLine` has picked by NAME
	-- out of `TREELINE.SPECIES` since part 3b, so a folder holding one model called `Spruce` plants
	-- NOTHING and quietly counts thirty fallbacks -- which is what this fake was doing.
	--
	-- AND THE FIRST ONE IS SCALED DOWN, because that is the bug this fixture exists to catch: the
	-- real `SilverBirch_Var11_LOD_0` sits in Studio at `GetScale() = 0.04329`, and `Model:ScaleTo`
	-- is ABSOLUTE against the authored size, so `ScaleTo(0.95)` rebuilt it at 0.95 of its raw import
	-- -- 1629 studs tall, twenty-two times the tree in the folder.
	local birch = model(CFG.TREELINE.SPECIES[1].MODEL, Vector3.new(6, 120, 6))
	birch:ScaleTo(0.25) -- it now DISPLAYS 1.5 x 30 x 1.5
	birch.Parent = trees
	model(CFG.TREELINE.SPECIES[2].MODEL, Vector3.new(6, 30, 6)).Parent = trees
	if withScript then
		local hidden = Instance.new("Script")
		hidden.Name = "Fire_Effect"
		hidden.Parent = lorry
	end
	return folder
end

local function corners(at: CFrame, size: Vector3): { Vector3 }
	local out = {}
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				table.insert(out, at.Position + Vector3.new(sx * size.X / 2, sy * size.Y / 2, sz * size.Z / 2))
			end
		end
	end
	return out
end

-- A BODY THAT IS NOT AN AVATAR (task 181). `Build` takes its rig source as a seam for exactly this
-- reason: the real one is `Players:CreateHumanoidModelFromDescription`, which reaches the avatar
-- service and may yield, and no spec in this harness may do either. It ships UNANCHORED and
-- COLLIDING, so "the keeper collides with nothing and his root is anchored" is a thing the builder
-- is proved to DO rather than a property the fake handed it.
-- A BODY WITH A REAL R15'S PROPORTIONS, AND SINCE TASK 195 THAT IS LOAD-BEARING. Until then every
-- part of this fake stood at the model's origin, so the rig was one stud tall and its root was its
-- own lowest point -- a body on which "are his feet on the floor?" and "does he reach into the
-- till?" are both unaskable, which is exactly why neither was ever asked.
--
-- EVERY NUMBER BELOW IS THE LIVE RIG'S, MEASURED in the Forest Test place on 2026-10-16
-- (`docs/research/2026-10-16-lodge-inside-clean.md` section 2): the root stands **3.188** studs
-- above the soles -- NOT the 3 that `KEEPER.ROOT_HEIGHT` guesses, which is the 0.188-stud sink
-- Karen saw -- and the hands' outer corners are **2.423** studs from the root in the horizontal
-- plane, which is the radius the service bay has to hold whichever way `faceKeeper` turns him.
--
-- THE LIMBS TOUCH, deliberately: the support case walks every part of the lodge's inside and this
-- body is in it, so a fake with a gap between a hand and an arm would fail a case about the
-- BUILDING.
local FAKE_RIG_PARTS = {
	{ name = "HumanoidRootPart", size = Vector3.new(2, 2, 1), at = Vector3.new(0, 3.188, 0) },
	{ name = "Head", size = Vector3.new(1.16, 1.18, 1.16), at = Vector3.new(0, 5.45, 0) },
	{ name = "UpperTorso", size = Vector3.new(2, 1.7, 1), at = Vector3.new(0, 4.02, 0) },
	{ name = "LowerTorso", size = Vector3.new(2, 0.42, 1), at = Vector3.new(0, 2.96, 0) },
	{ name = "LeftUpperArm", size = Vector3.new(1, 1.24, 1), at = Vector3.new(-1.5, 4.26, 0) },
	{ name = "RightUpperArm", size = Vector3.new(1, 1.24, 1), at = Vector3.new(1.5, 4.26, 0) },
	{ name = "LeftLowerArm", size = Vector3.new(1, 1.12, 1), at = Vector3.new(-1.5, 3.1, 0) },
	{ name = "RightLowerArm", size = Vector3.new(1, 1.12, 1), at = Vector3.new(1.5, 3.1, 0) },
	{ name = "LeftHand", size = Vector3.new(0.984, 0.316, 1.028), at = Vector3.new(-1.733, 2.4, 0) },
	{ name = "RightHand", size = Vector3.new(0.984, 0.316, 1.028), at = Vector3.new(1.733, 2.4, 0) },
	{ name = "LeftUpperLeg", size = Vector3.new(1, 1.36, 1), at = Vector3.new(-0.5, 2.34, 0) },
	{ name = "RightUpperLeg", size = Vector3.new(1, 1.36, 1), at = Vector3.new(0.5, 2.34, 0) },
	{ name = "LeftLowerLeg", size = Vector3.new(1, 1.3, 1), at = Vector3.new(-0.5, 1.16, 0) },
	{ name = "RightLowerLeg", size = Vector3.new(1, 1.3, 1), at = Vector3.new(0.5, 1.16, 0) },
	{ name = "LeftFoot", size = Vector3.new(1, 0.312, 1), at = Vector3.new(-0.5, 0.156, 0) },
	{ name = "RightFoot", size = Vector3.new(1, 0.312, 1), at = Vector3.new(0.5, 0.156, 0) },
}

local function fakeRig(): Model
	local model = Instance.new("Model")
	local root: BasePart? = nil
	for _, spec in ipairs(FAKE_RIG_PARTS) do
		local limb = Instance.new("Part")
		limb.Name = spec.name
		limb.Size = spec.size
		limb.CFrame = CFrame.new(spec.at)
		limb.Anchored = false
		limb.CanCollide = true
		limb.CanQuery = true
		limb.CanTouch = true
		limb.Parent = model
		if spec.name == "HumanoidRootPart" then
			root = limb
		end
	end
	local humanoid = Instance.new("Humanoid")
	-- THE LIVE RIG'S OWN FIGURE, and it is the one the build reads: `Humanoid.HipHeight` is the
	-- distance from the ROOT PART'S BOTTOM to the ground, so 2.192 on a 2-stud root puts the root's
	-- centre 3.192 studs over the floorboards -- which is where this fake's soles are (3.188, a
	-- float apart). A Humanoid left at its default would make the two disagree and the keeper's
	-- feet a coincidence.
	humanoid.HipHeight = 2.192
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

return function()
	describe("where the lobby lives", function()
		it("has a row for the world Karen plays in and none for the harness's", function()
			local forest = Data.anchorFor("forest-test")
			expect(forest).to.be.ok()
			-- The MEASURED flattest open ground south of `OurForest`'s southern edge (z = -2896).
			expect((forest :: any).x).to.equal(2850)
			expect((forest :: any).z).to.equal(-2950)

			-- THE DEV PLACE HAS NO LOBBY IN THIS TASK, so the harness reads exactly what it read
			-- before it: no anchor, no build, no terrain write.
			expect(Data.anchorFor("map:v1")).to.equal(nil)
			expect(Data.anchorFor("arena")).to.equal(nil)
			expect(Data.anchorFor("not-a-world")).to.equal(nil)
			expect(Data.anchorFor(nil)).to.equal(nil)
		end)

		it("carries no Y, because nobody measured one", function()
			-- The anchor is x and z only: the shelf's height comes from the world's own ground reader
			-- at build time. A typed Y would be a guess that puts the lodge in the air.
			local forest = Data.anchorFor("forest-test") :: any
			expect(forest.y).to.equal(nil)
		end)

		-- IT IS A DISTANCE BETWEEN TWO RECTANGLES NOW, AND NOT A z COMPARISON (task 179).
		--
		-- This case used to read `forest.z < ForestTest.EXIT_Z` and `CENTRE.Z - forest.z > 500`, and
		-- BOTH became false: `EXIT_Z` is gone, and the `edge` layout's exit is z -3250 -- which is
		-- SOUTH of the lodge at -2950. A z comparison was only ever a proxy for *"the lodge is not
		-- in the way"*, and with three layouts in three different parts of the wood it is the wrong
		-- question: the edge drive is 255 studs EAST of the lodge, not north of it.
		--
		-- EACH OWNER STATES ITS OWN RECTANGLE and this spec is the only place the two meet --
		-- `ForestTest.corridorOf` is the forest's, `Lobby.anchorFor` plus `Lobby.CONFIG.FIELD` is
		-- the lobby's. Making either module require the other for one assertion would be new
		-- coupling for nothing.
		local function gapStuds(a, b): number
			local dx = math.max(a.minX - b.maxX, b.minX - a.maxX, 0)
			local dz = math.max(a.minZ - b.maxZ, b.minZ - a.maxZ, 0)
			-- 0 on either axis with the other positive is a side-on gap; both positive is a corner.
			return if dx > 0 and dz > 0 then math.sqrt(dx * dx + dz * dz) else math.max(dx, dz)
		end

		-- TASK 302: IT IS THE WHOLE UNION NOW, NOT THE LODGE'S SQUARE. `Join.homeAreas` added two
		-- more rectangles in Karen's place -- the range's footprint and the walk to it -- and
		-- "clear of the drive" is a claim about every one of them. Each gap is PRINTED, so a case
		-- that silently checked an empty list could not read as a pass (L-128).
		it("is clear of EVERY drive layout's ground, so it cannot interact with the drive", function()
			local forest = Data.anchorFor("forest-test") :: any
			local ForestTest = require(ReplicatedStorage:WaitForChild("ForestTest"))
			local Boar = require(ServerScriptService:WaitForChild("Boar"))
			local RangeData = require(ReplicatedStorage:WaitForChild("Range"))
			local anchor = Vector3.new(forest.x, 0, forest.z)
			local row = RangeData.anchorFor("forest-test") :: any
			local footprint =
				RangeData.footprintFor(Vector3.new(row.x, 0, row.z), RangeData.LAYOUT, RangeData.downrangeOf(row))
			local rects = Join.homeAreas(anchor, Data.CONFIG, { footprint })
			-- The field, the range and the walkway: three, and the count is asserted so a nil
			-- `extras` could never make this case check one rectangle and still pass.
			expect(#rects).to.equal(3)
			expect(#ForestTest.LAYOUT_ORDER > 0).to.equal(true)
			local checks = 0
			local worstCorridor, worstBounds = math.huge, math.huge
			local exits = {}
			for _, name in ipairs(ForestTest.LAYOUT_ORDER) do
				local layout = ForestTest.layoutNamed(name)
				table.insert(exits, string.format("%s exitZ %.0f", name, ForestTest.exitZOf(layout)))
				-- The ground a drive happens on: the stands' span, from the exit to the beaters'
				-- start. Nobody stands, walks or is placed outside it.
				local corridor = ForestTest.corridorOf(layout)
				local bounds = ForestTest.boundsOf(layout)
				for index, rect in ipairs(rects) do
					local corridorGap = gapStuds(corridor, rect)
					worstCorridor = math.min(worstCorridor, corridorGap)
					expect(corridorGap >= 100).to.equal(
						true,
						string.format(
							"layout %s: corridor is only %.0f studs from home rectangle %d",
							name,
							corridorGap,
							index
						)
					)
					-- ...and the rectangle a boar may be clamped into, which is wider than the
					-- corridor.
					local boundsGap = gapStuds(bounds, rect)
					worstBounds = math.min(worstBounds, boundsGap)
					expect(boundsGap >= Boar.CONFIG.BOUNDS_SLACK + 40).to.equal(
						true,
						string.format(
							"layout %s: boar bounds are only %.0f studs from home rectangle %d",
							name,
							boundsGap,
							index
						)
					)
					checks += 1
				end
			end
			-- Four layouts times three rectangles, and the number is asserted rather than assumed.
			expect(checks).to.equal(#ForestTest.LAYOUT_ORDER * #rects)
			TestKit.note(
				string.format(
					"home vs drive: %d pairs checked over %d layouts; worst corridor gap %.0f studs,"
						.. " worst boar-bounds gap %.0f studs; %s",
					checks,
					#ForestTest.LAYOUT_ORDER,
					worstCorridor,
					worstBounds,
					table.concat(exits, ", ")
				)
			)
		end)
	end)

	-- ---------------------------------------------------------------- the pads (task 182)
	--
	-- KAREN, 2026-10-14: *"you come to truck back rectangle and can click and select how many
	-- players ... can be 1/1 or 4/4"*.
	--
	-- `Lobby.Pads` IS PURE, which is why every state, every transition and every boundary second is a
	-- table of cases stated here rather than a thing somebody watches in a playtest. Task 177's
	-- `Join.within` and `Join.decide` cases are REPLACED by these: the circle is gone and the
	-- countdown belongs to the pad now (both archived in
	-- `backups/2026-10-14_task-182_the-marked-circle.txt`).
	describe("the pads: the rectangle (Valve's trigger_multiple, read as arithmetic)", function()
		local SIZE = CFG.PADS.SIZE

		it("is a RECTANGLE, flat, and ON any edge -- or a CORNER -- is IN it", function()
			local centre = Vector3.new(100, 20, -50)
			expect(Join.withinRect(centre, centre, SIZE)).to.equal(true)
			-- ON each edge, both axes: the same `<=` every other presence test in this repo makes.
			expect(Join.withinRect(centre + Vector3.new(SIZE.X / 2, 0, 0), centre, SIZE)).to.equal(true)
			expect(Join.withinRect(centre - Vector3.new(SIZE.X / 2, 0, 0), centre, SIZE)).to.equal(true)
			expect(Join.withinRect(centre + Vector3.new(0, 0, SIZE.Z / 2), centre, SIZE)).to.equal(true)
			expect(Join.withinRect(centre - Vector3.new(0, 0, SIZE.Z / 2), centre, SIZE)).to.equal(true)
			-- ...and just past each of them.
			expect(Join.withinRect(centre + Vector3.new(SIZE.X / 2 + 0.01, 0, 0), centre, SIZE)).to.equal(false)
			expect(Join.withinRect(centre + Vector3.new(0, 0, SIZE.Z / 2 + 0.01), centre, SIZE)).to.equal(false)
			-- A CORNER IS IN, AND THAT IS THE WHOLE DIFFERENCE FROM TASK 177'S CIRCLE: an inscribed
			-- circle would call the four corners of Karen's own rectangle "not the pad".
			expect(Join.withinRect(centre + Vector3.new(SIZE.X / 2, 0, SIZE.Z / 2), centre, SIZE)).to.equal(true)
			-- FLAT: fifty studs above or below is still on it -- a man on the truck's running board.
			expect(Join.withinRect(centre + Vector3.new(0, 50, 0), centre, SIZE)).to.equal(true)
			expect(Join.withinRect(centre - Vector3.new(0, 50, 0), centre, SIZE)).to.equal(true)
		end)

		-- ---------------------------------------------------------- task 213, Karen's gap
		--
		-- KAREN, 2026-10-18, with a screenshot: *"car has to be moved back meaning left same size
		-- twice as car now is (screenshoot) so I can easy access enter to game"* -- task 209, which
		-- measured her gap at 2.77 studs and opened it to 18.77.
		-- KAREN, 2026-10-19, looking at that: *"truck is good, now can make pods closer to truck"*.
		-- Measured on her own path first again (rule H): the built gaps were 18.74 / 18.77 / 18.77 /
		-- 18.41 -- a truck's whole length of gravel between her rectangle and her truck.
		--
		-- **THE AXIS TURNED IN TASK 243 AND THE GAP DID NOT.** The row steps SOUTH now and the truck
		-- faces WEST, so the gap is between the pad's EAST edge and the truck's drawn NOSE -- 3.77
		-- studs, the same number task 213 settled, on x instead of z.
		--
		-- THE RULE IS A BAND IN THE DATA (`TRUCK.PAD_GAP_STUDS`) AND NOT A LITERAL HERE, because the
		-- gap is EMERGENT: `PAD_BEHIND_STUDS`, `BACK_STUDS` and `MODEL.LENGTH_STUDS` each move it, and
		-- a retune of any one of them could walk it out of *"closer"* with nothing to catch it. It
		-- replaces task 209's *"at least two truck-widths"*, which is the same sentence with her older
		-- number in it: the truck did not move in 213, the pad did.
		--
		-- EVERY BAY, NOT THE ONE IN THE SCREENSHOT (L-093): each pair is measured at its own z, and bay
		-- 4's truck is the one the hill tilts.
		it("leaves one short step -- not a walk -- between every pad and its own truck (task 213)", function()
			local anchor = Vector3.new(0, 100, 0)
			local model = CFG.TRUCK.MODEL
			local band = CFG.TRUCK.PAD_GAP_STUDS
			-- A BAND THAT ALLOWS ZERO WOULD ALLOW THE PAD UNDER THE BUMPER, so the band itself is
			-- asserted before anything is measured against it.
			expect(band.MIN > 0).to.equal(true)
			expect(band.MAX > band.MIN).to.equal(true)
			for index = 1, CFG.TRUCK.COUNT do
				local centre = Pads.centreFor(anchor, index, CFG)
				local bayX = anchor.X + CFG.TRUCK.OFFSET.X
				-- the parked body's own west face: half its length, pushed east by `BACK_STUDS`
				local noseX = bayX + CFG.TRUCK.BACK_STUDS - model.LENGTH_STUDS / 2
				local gap = noseX - (centre.X + SIZE.X / 2)
				expect(gap >= band.MIN).to.equal(true)
				expect(gap <= band.MAX).to.equal(true)
				-- ...AND SAID THE OTHER WAY ROUND: the pad and the parked body never share a stud, which
				-- is the half of it a player feels rather than measures.
				expect(gap > 0).to.equal(true)
				-- THE TRUCK IS STILL EAST OF ITS PAD AND NOT THE OTHER WAY, so "closer" never becomes
				-- "through", and `Camera.faceTowards` still turns a man on the pad toward a truck.
				expect(noseX > centre.X + SIZE.X / 2).to.equal(true)
			end
		end)

		-- THE YARD IS ONE RECTANGLE WITH TWO READERS (`Build.road`'s slab and `Build.trees`'
		-- exclusion), and it has to carry everything task 209 moved apart: if it does not, a truck
		-- stands with its rear wheels off the gravel or a spruce grows on a queue pad.
		it("keeps every truck and every pad on the yard rectangle (task 209)", function()
			local anchor = Vector3.new(0, 100, 0)
			local midX, halfX, midZ, halfZ = Build.yardRect(anchor, CFG)
			local model = CFG.TRUCK.MODEL
			for index = 1, CFG.TRUCK.COUNT do
				-- **THE BAY STEPS SOUTH AND THE TRUCK STANDS EAST OF IT** (task 243). The truck's
				-- LENGTH is along x now and its WIDTH along z, which is the whole of what changed.
				local bayZ = anchor.Z + CFG.TRUCK.OFFSET.Z - (index - 1) * CFG.TRUCK.BAY_GAP_STUDS
				local truckX = anchor.X + CFG.TRUCK.OFFSET.X + CFG.TRUCK.BACK_STUDS
				-- the truck's four corners
				expect(math.abs(truckX - midX) + model.LENGTH_STUDS / 2 <= halfX).to.equal(true)
				expect(math.abs(bayZ - midZ) + model.WIDTH_STUDS / 2 <= halfZ).to.equal(true)
				-- ...and the pad's
				local centre = Pads.centreFor(anchor, index, CFG)
				expect(math.abs(centre.X - midX) + SIZE.X / 2 <= halfX).to.equal(true)
				expect(math.abs(centre.Z - midZ) + SIZE.Z / 2 <= halfZ).to.equal(true)
			end
		end)

		it("puts one pad in front of each bay, clear of the lodge, the noses, the trees and the field", function()
			-- EVERY CLEARANCE IN `docs/design/truck-pads.md` SECTION 4.1, AS ARITHMETIC OVER THE
			-- CONFIG AND NEVER A LITERAL -- so a retune of `SIZE` or `BAY_GAP_STUDS` that breaks one
			-- fails the harness instead of looking wrong in a screenshot.
			--
			-- **TASK 243 TURNED EVERY ONE OF THESE NINETY DEGREES AND CHANGED NO VALUE.** The pad is
			-- WEST of its bay (it was north), the row steps SOUTH (it stepped east), and the pad is
			-- 12 deep by 9 wide (it was 9 by 12). The lodge bounds below are the ones that moved
			-- FURTHEST clear: pad 1's west face stood 3.5 studs off the lodge's east wall and now
			-- stands 23.
			local anchor = Vector3.new(0, 100, 0)
			local half = CFG.FIELD.SPAN_STUDS / 2
			local lastSouth = math.huge
			for index = 1, CFG.TRUCK.COUNT do
				local centre = Pads.centreFor(anchor, index, CFG)
				-- z: THE BAY'S OWN z, the same expression `Build.trucks` steps with.
				expect(centre.Z).to.equal(anchor.Z + CFG.TRUCK.OFFSET.Z - (index - 1) * CFG.TRUCK.BAY_GAP_STUDS)
				-- x: `PAD_BEHIND_STUDS` from the BAY CENTRE to the pad's NEAR edge, which is its
				-- EAST edge now -- the edge the truck is on.
				local nearEdge = centre.X + SIZE.X / 2
				expect(nearEdge).to.equal(anchor.X + CFG.TRUCK.OFFSET.X - CFG.TRUCK.PAD_BEHIND_STUDS)
				-- ...WHICH CLEARS BOTH NOSES. The parts truck's `Bumper` face is at `-10.0` of its
				-- own frame; the free model is 18.46 long, so 9.23 -- and both are parked
				-- `BACK_STUDS` EAST of the bay, so both come forward by that much.
				local bayX = anchor.X + CFG.TRUCK.OFFSET.X
				expect(nearEdge < bayX + CFG.TRUCK.BACK_STUDS - 10.0).to.equal(true)
				expect(nearEdge < bayX + CFG.TRUCK.BACK_STUDS - CFG.TRUCK.MODEL.LENGTH_STUDS / 2).to.equal(true)
				-- THE TREE LINE'S YARD EXCLUSION IS `Build.yardRect` PLUS FOUR STUDS (it was the
				-- literal z +44 until task 209 derived the rectangle), so the pad has to stay
				-- inside it on BOTH axes or a tree can stand on a pad.
				local yardMidX, yardHalfX, yardMidZ, yardHalfZ = Build.yardRect(anchor, CFG)
				expect(centre.X - SIZE.X / 2 >= yardMidX - yardHalfX - 4).to.equal(true)
				expect(centre.Z - SIZE.Z / 2 >= yardMidZ - yardHalfZ - 4).to.equal(true)
				expect(centre.Z + SIZE.Z / 2 <= yardMidZ + yardHalfZ + 4).to.equal(true)
				-- EVERY CORNER IS ON THE FIELD.
				expect(math.abs(centre.X - anchor.X) + SIZE.X / 2 <= half).to.equal(true)
				expect(math.abs(centre.Z - anchor.Z) + SIZE.Z / 2 <= half).to.equal(true)
				-- THE FOUR RECTANGLES ARE DISJOINT, which is what lets `Pads.indexAt` return on its
				-- first match. They step SOUTH, so each one's north edge is south of the last one's.
				expect(centre.Z + SIZE.Z / 2 < lastSouth).to.equal(true)
				lastSouth = centre.Z - SIZE.Z / 2
				-- THE SLAB IS SUNK: its TOP is above the yard's own road-thick surface and its BOTTOM
				-- is below the shelf, so nothing floats and nothing can hide inside a slab (task
				-- 177's round-1 finding, closed in advance).
				-- A TOLERANCE AND NOT AN EQUALITY, because a `Vector3`'s components are 32-bit: the
				-- measured answer is 100.58000335097313 for an arithmetic 100.58, which is the same
				-- surface and a different number (`viewmodel_poses.spec`'s own rule for a value that
				-- makes a round trip).
				local top = centre.Y + SIZE.Y / 2
				expect(math.abs(top - (anchor.Y + CFG.ROAD.THICK_STUDS + CFG.PADS.LIFT_STUDS)) < 1e-3).to.equal(true)
				expect(centre.Y - SIZE.Y / 2 < anchor.Y).to.equal(true)
			end
			-- PAD 1 CLEARS THE PARTS LODGE'S EAST WALL, whose outer face is `LODGE.SIZE.X / 2 +
			-- LOG_DIAMETER / 2` east of the lodge's own offset -- the bound that made 14 studs wide
			-- impossible.
			local wallX = anchor.X + CFG.LODGE.OFFSET.X + CFG.LODGE.SIZE.X / 2 + CFG.LODGE.LOG_DIAMETER / 2
			expect(Pads.centreFor(anchor, 1, CFG).X - SIZE.X / 2 >= wallX).to.equal(true)
			-- ...AND ITS ROOF AND ITS PORCH, WHICH IS A NEW BOUND SINCE TASK 213 AND NOT A SPARE ONE.
			-- The pads used to sit at z +38..+50, north of the porch entirely; at `PAD_BEHIND_STUDS` 5
			-- they sat in the porch's own z band, so pad 1's west face has to clear the two things
			-- that overhang furthest on the lodge's EAST side rather than only the wall below them:
			--   * the main roof's gable overhang, `SIZE.X / 2 + ROOF.GABLE_STUDS` (`Build.roof`'s own
			--     expression; `EAVE_STUDS` is the z overhang and the chimney is on the WEST end), and
			--   * the porch, which is INSET from the house (`Build.porch`: `size.X - INSET_STUDS * 2`)
			--     and so is narrower than either.
			local gableX = anchor.X + CFG.LODGE.OFFSET.X + CFG.LODGE.SIZE.X / 2 + CFG.LODGE.ROOF.GABLE_STUDS
			expect(Pads.centreFor(anchor, 1, CFG).X - SIZE.X / 2 >= gableX).to.equal(true)
			local porchX = anchor.X + CFG.LODGE.OFFSET.X + (CFG.LODGE.SIZE.X - CFG.LODGE.PORCH.INSET_STUDS * 2) / 2
			expect(Pads.centreFor(anchor, 1, CFG).X - SIZE.X / 2 >= porchX).to.equal(true)
			-- ...AND THERE IS ONE PART NAME PER BAY, so four trucks and three pads cannot happen.
			expect(#CFG.PADS.PART_NAMES).to.equal(CFG.TRUCK.COUNT)
			expect(Data.padCount()).to.equal(CFG.TRUCK.COUNT)
			-- PAD 1 IS STILL `TruckSpot`, which is what `Lobby.spotPart`, the Hud's chevron and the
			-- Director's own `smoke.sh` find it by.
			expect(Data.padPartName(1)).to.equal(Data.SPOT_NAME)
		end)

		-- **TASK 243: THE FOUR THINGS THE TURNED YARD HAS TO KEEP TRUE**, which are the Designer's
		-- own "what a spec should assert, so none of this drifts back" (`lobby-yard-spec.md`
		-- section 5). Each one is a thing that was WRONG in the shipped build and that nothing but a
		-- picture would have caught.
		it("keeps the turned yard off the fence, off the grove and inside the tree line (task 243)", function()
			local anchor = Vector3.new(0, 100, 0)
			local midX, halfX, midZ, halfZ = Build.yardRect(anchor, CFG)

			-- **1. THE GRAVEL STARTS AT THE ROAD'S EAST VERGE, NOT AT ITS CENTRE LINE.** Written to
			-- `ROAD.CENTRE_X` the rectangle put half the lane inside the yard; at the verge the two
			-- surfaces abut and the lane stays a lane.
			expect(midX - halfX).to.be.near(
				anchor.X + CFG.ROAD.CENTRE_X + CFG.ROAD.WIDTH_STUDS / 2 + CFG.ROAD.VERGE_STUDS,
				1e-6
			)

			-- **2. NO `LODGE_TREES` TRUNK IS INSIDE THE GRAVEL.** `lodgeTrees` plants exactly what
			-- that table says and NO exclusion reads it -- the `yardRect` guard belongs to
			-- `treeLine`'s procedural arc -- so a birch in the middle of the truck yard would be a
			-- ROW and not a bug to be caught downstream.
			--
			-- **AND IT IS ASSERTED IN THE LODGE'S FRAME, WHICH IS THE ONE `Build.lodgeTrees` PLANTS
			-- IN.** `lobby-yard-spec.md` section 2f asks for rows 5 and 7 to move because *"both
			-- fall inside the new gravel"*; read in the lodge's frame -- `anchor + LODGE.OFFSET +
			-- (x, z)`, and the lodge stands at z +46 -- they sit 27 and 33 studs north of the
			-- gravel's edge and have not moved. This case is what makes that answerable either way.
			for _, row in ipairs(CFG.LODGE_TREES) do
				local x = anchor.X + CFG.LODGE.OFFSET.X + row.x
				local z = anchor.Z + CFG.LODGE.OFFSET.Z + row.z
				local inside = math.abs(x - midX) <= halfX and math.abs(z - midZ) <= halfZ
				expect(inside).to.equal(false)
			end

			-- **3. THE YARD'S EAST EDGE IS UNDER THE TREE ARC'S OWN CEILING.** `treeLine` SKIPS any
			-- tree that lands inside this rectangle, so a yard pushed further out at "the trees"
			-- punches a hole in the wood directly behind the trucks: at bay x 70 the gravel reaches
			-- 91.2 and the arc's own x over the yard's z band runs 80.8 .. 89.1, ALL of it inside.
			-- The ceiling is the SMALLEST `RADIUS * sin(a)` over every bearing whose
			-- `RADIUS * cos(a)` falls in the band, and the yard has to stay below it.
			-- **THE ARC IS SAMPLED AT ITS INNERMOST RADIUS**, `RADIUS_STUDS - JITTER_STUDS`, because
			-- the jitter is what actually decides which trunks the exclusion can reach -- the
			-- Designer's own 80.8 is that number and not the nominal arc's 89.9. `treeLine`'s own
			-- `+ 4` exclusion margin is deliberately NOT folded in: it is slack the guard has always
			-- carried, and the live build still plants 27 ring trees, the same count as before the
			-- row turned.
			local ceiling = math.huge
			local steps = 2000
			local spec = CFG.TREELINE
			local inner = spec.RADIUS_STUDS - spec.JITTER_STUDS
			for step = 0, steps do
				local angle = spec.FROM_RADIANS + (spec.TO_RADIANS - spec.FROM_RADIANS) * (step / steps)
				local z = anchor.Z + math.cos(angle) * inner
				local x = anchor.X + math.sin(angle) * inner
				if x > anchor.X and math.abs(z - midZ) <= halfZ then
					ceiling = math.min(ceiling, x)
				end
			end
			expect(ceiling < math.huge).to.equal(true)
			expect(midX + halfX < ceiling).to.equal(true)
			TestKit.note(
				string.format(
					"lobby: the yard's east edge is %.2f against the tree arc's own ceiling of %.2f",
					midX + halfX,
					ceiling
				)
			)

			-- **4. THE FENCE STOPS SOUTH OF THE GRAVEL**, by at least the yard's own lip. Forty
			-- studs of post-and-rail stood inside the new yard until `FENCE.TO_Z` came south with
			-- it -- and `CONFIG.FENCE`'s own comment had always asked for this; only the number was
			-- pinned to the old rectangle.
			expect(CFG.FENCE.TO_Z <= midZ - halfZ - CFG.ROAD.YARD_LIP_STUDS).to.equal(true)

			-- **5. THE BLADE-FREE BLOCK COVERS THE WHOLE OF THE GRAVEL PLUS ITS LIP.** A slab laid
			-- on grass does not hide the grass: Roblox draws a `Grass` material's blades on the
			-- terrain surface, which is why the first road came back as *"a field and NO ROAD"*.
			local yard = nil
			for _, pad in ipairs(CFG.FIELD.PADS) do
				if pad.NAME == "Yard" then
					yard = pad
				end
			end
			expect(yard).to.be.ok()
			local lip = CFG.ROAD.YARD_LIP_STUDS
			local blockX, blockZ = anchor.X + (yard :: any).OFFSET.X, anchor.Z + (yard :: any).OFFSET.Z
			local blockHalf = (yard :: any).SIZE
			expect(blockX - blockHalf.X / 2 <= midX - halfX - lip).to.equal(true)
			expect(blockX + blockHalf.X / 2 >= midX + halfX + lip).to.equal(true)
			expect(blockZ - blockHalf.Z / 2 <= midZ - halfZ - lip).to.equal(true)
			expect(blockZ + blockHalf.Z / 2 >= midZ + halfZ + lip).to.equal(true)

			-- **6. ...AND ITS FOUR EDGES LAND ON THE 4-STUD VOXEL GRID.** `Terrain:FillBlock` writes
			-- 4-stud voxels on a grid anchored at the world origin, and task 191 measured two grass
			-- voxels surviving at a misaligned edge. This is asserted at the REAL anchor and not at
			-- the test's (0, 100, 0), because the grid is a property of where the block falls in the
			-- world -- which is exactly the trap the Designer's own step 8 warns about.
			local real = Data.anchorFor("forest-test")
			expect(real).to.be.ok()
			for _, edge in ipairs({
				(real :: any).x + (yard :: any).OFFSET.X - blockHalf.X / 2,
				(real :: any).x + (yard :: any).OFFSET.X + blockHalf.X / 2,
				(real :: any).z + (yard :: any).OFFSET.Z - blockHalf.Z / 2,
				(real :: any).z + (yard :: any).OFFSET.Z + blockHalf.Z / 2,
			}) do
				expect(math.abs(edge % 4) < 1e-6).to.equal(true)
			end
		end)

		it("answers which pad a position is on, and nil for the gap, the field and no character", function()
			local anchor = Vector3.new(0, 100, 0)
			for index = 1, CFG.TRUCK.COUNT do
				expect(Pads.indexAt(Pads.centreFor(anchor, index, CFG), anchor, CFG)).to.equal(index)
			end
			-- THE 8-STUD GAP BETWEEN TWO PADS belongs to neither.
			local between = (Pads.centreFor(anchor, 1, CFG) + Pads.centreFor(anchor, 2, CFG)) / 2
			expect(Pads.indexAt(between, anchor, CFG)).to.equal(nil)
			-- ...AND SO DOES THE REST OF THE FIELD.
			expect(Pads.indexAt(anchor, anchor, CFG)).to.equal(nil)
			expect(Pads.indexAt(anchor + Vector3.new(0, 0, 200), anchor, CFG)).to.equal(nil)
			-- nil POSITION -> nil. A player with no character is standing NOWHERE, and absent is not
			-- outside: `Join.needsReturn`'s rule and `MapUi.pointsFor`'s.
			expect(Pads.indexAt(nil, anchor, CFG)).to.equal(nil)
		end)
	end)

	describe("the pads: the state machine", function()
		local PADS = CFG.PADS

		local function who(...): { any }
			local out = {}
			for _, userId in ipairs({ ... }) do
				table.insert(out, { userId = userId, since = 0 })
			end
			return out
		end

		it("asks the FIRST man on an empty pad, and asks nobody twice", function()
			local pad = Pads.empty(2)
			expect(pad.state).to.equal(Pads.EMPTY)
			expect(pad.index).to.equal(2)
			local after, verdict = Pads.step(pad, who(11, 22, 33), 1, CFG)
			expect(verdict).to.equal(Pads.ASK)
			expect(after.state).to.equal(Pads.SIZING)
			expect(after.firstUserId).to.equal(11)
			expect(after.size).to.equal(nil)
			expect(after.deadline).to.equal(1 + PADS.PICK_TIMEOUT_SECONDS)
			expect(#after.members).to.equal(3)
			-- `ASK` IS AN EDGE, because the owner turns it into an attribute write.
			local third, second = Pads.step(after, who(11, 22, 33), 1.1, CFG)
			expect(second).to.equal(Pads.NONE)
			expect(third.firstUserId).to.equal(11)
			expect(third.deadline).to.equal(after.deadline)
			-- AN EMPTY PAD THAT STAYS EMPTY SAYS NOTHING EITHER.
			expect(select(2, Pads.step(Pads.empty(1), {}, 5, CFG))).to.equal(Pads.NONE)
		end)

		it("elects the man who has been standing there longest, and breaks a tie by userId", function()
			-- `since` EXISTS FOR EXACTLY THIS. The member list is re-measured every scan and may
			-- arrive in any order, so "the first man on" cannot be "the first in the list".
			local late = { { userId = 11, since = 9 }, { userId = 22, since = 2 }, { userId = 33, since = 5 } }
			expect(select(1, Pads.step(Pads.empty(1), late, 10, CFG)).firstUserId).to.equal(22)
			local tied = { { userId = 44, since = 3 }, { userId = 22, since = 3 } }
			expect(select(1, Pads.step(Pads.empty(1), tied, 10, CFG)).firstUserId).to.equal(22)
		end)

		it("takes a pick only while it is asking, and only one of the four sizes", function()
			local pad = select(1, Pads.step(Pads.empty(1), who(11, 22), 1, CFG))
			-- A SIZE THAT IS NOT ON THE LIST CHANGES NOTHING: a forged or stale payload.
			for _, bad in ipairs({ 3, 7, 9, 0, -1, 1.5, "4", true }) do
				local nope, ok = Pads.withSize(pad, bad :: any, 1.2, CFG)
				expect(ok).to.equal(false)
				expect(nope.size).to.equal(nil)
				expect(nope.state).to.equal(Pads.SIZING)
			end
			expect(Pads.sizeAllowed(nil, CFG)).to.equal(false)
			expect(Pads.sizeAllowed(0 / 0, CFG)).to.equal(false)
			-- ...AND THE FOUR THAT ARE.
			for _, row in ipairs(PADS.SIZES) do
				expect(Pads.sizeAllowed(row.size, CFG)).to.equal(true)
				local sized, ok = Pads.withSize(pad, row.size, 1.2, CFG)
				expect(ok).to.equal(true)
				expect(sized.state).to.equal(Pads.FILLING)
				expect(sized.size).to.equal(row.size)
				expect(sized.deadline).to.equal(1.2 + PADS.FILL_TIMEOUT_SECONDS)
				-- `firstUserId` SURVIVES THE PICK, which is what lets `Lobby.padAsking` gate the
				-- dialog on the STATE and still answer "who picked".
				expect(sized.firstUserId).to.equal(11)
			end
			-- A PAD THAT IS NOT ASKING TAKES NO PICK AT ALL: every other state refuses.
			local filling = select(1, Pads.withSize(pad, 4, 1.2, CFG))
			for _, state in ipairs({ Pads.EMPTY, Pads.FILLING, Pads.COUNTDOWN, Pads.LEAVING }) do
				local other = table.clone(filling)
				other.state = state
				expect(select(2, Pads.withSize(other, 2, 1.3, CFG))).to.equal(false)
			end
		end)

		it("defaults the pick to ONE after PICK_TIMEOUT_SECONDS, and reaches the drive unattended", function()
			-- THIS IS THE PATH THE DIRECTOR'S OWN SMOKE CHECK TAKES, with no click and no dialog
			-- (design section 15.4): a snippet run over StudioMCP gets a sandboxed copy of the
			-- server's modules with empty state (measured, task 122), so it can neither pick a size
			-- nor press a button.
			local pad = select(1, Pads.step(Pads.empty(1), who(11), 1, CFG))
			-- ONE TICK BEFORE THE TIMEOUT: still asking.
			local waiting = select(1, Pads.step(pad, who(11), 1 + PADS.PICK_TIMEOUT_SECONDS - 0.05, CFG))
			expect(waiting.state).to.equal(Pads.SIZING)
			-- AT IT: sized at row 1, which is 1.
			local sized, set = Pads.step(pad, who(11), 1 + PADS.PICK_TIMEOUT_SECONDS, CFG)
			expect(set).to.equal(Pads.SET)
			expect(sized.size).to.equal(1)
			expect(sized.size).to.equal(Pads.defaultSize(CFG))
			-- ONE TRANSITION PER CALL, so the countdown starts on the NEXT scan and not in this one.
			expect(sized.state).to.equal(Pads.FILLING)
			local armed, verdict = Pads.step(sized, who(11), 1 + PADS.PICK_TIMEOUT_SECONDS + 0.1, CFG)
			expect(verdict).to.equal(Pads.ARMED)
			expect(armed.state).to.equal(Pads.COUNTDOWN)
			expect(armed.deadline).to.equal(1 + PADS.PICK_TIMEOUT_SECONDS + 0.1 + CFG.COUNTDOWN_SECONDS)
			-- THE WHOLE WALK-ON-TO-GONE, TWO SCANS OF SLACK INCLUDED, HAS TO FIT INSIDE AN UNATTENDED
			-- SMOKE WINDOW -- asserted rather than believed, because the number is load-bearing.
			expect(PADS.PICK_TIMEOUT_SECONDS + CFG.COUNTDOWN_SECONDS + 2 / CFG.SCAN_HZ < 20).to.equal(true)
		end)

		it("counts down when the party is FULL, and when the fill times out", function()
			local pad = select(1, Pads.withSize(select(1, Pads.step(Pads.empty(1), who(11), 1, CFG)), 4, 1.2, CFG))
			expect(pad.state).to.equal(Pads.FILLING)
			-- THREE OF FOUR: still filling, and a join is not a verdict.
			local three, quiet = Pads.step(pad, who(11, 22, 33), 2, CFG)
			expect(three.state).to.equal(Pads.FILLING)
			expect(quiet).to.equal(Pads.NONE)
			expect(three.deadline).to.equal(pad.deadline)
			-- THE FOURTH ARRIVES: the countdown, at task 177's own five seconds.
			local full, armed = Pads.step(three, who(11, 22, 33, 44), 3, CFG)
			expect(armed).to.equal(Pads.ARMED)
			expect(full.state).to.equal(Pads.COUNTDOWN)
			expect(full.deadline).to.equal(3 + CFG.COUNTDOWN_SECONDS)
			-- SIZE IS A TARGET AND NOT A CAP: a ninth man is in the party, because keeping him off
			-- the slab would mean MOVING him and this owner may not write a character's position.
			local over = select(1, Pads.step(three, who(11, 22, 33, 44, 55), 3, CFG))
			expect(#over.members).to.equal(5)
			expect(over.state).to.equal(Pads.COUNTDOWN)
			-- NOBODY ELSE COMES: the fill times out and the part-full party goes anyway.
			local lonely = select(1, Pads.step(pad, who(11, 22), 1.2 + PADS.FILL_TIMEOUT_SECONDS, CFG))
			expect(lonely.state).to.equal(Pads.COUNTDOWN)
			-- ...AND ONE TICK EARLIER IT DID NOT.
			local nearly = select(1, Pads.step(pad, who(11, 22), 1.2 + PADS.FILL_TIMEOUT_SECONDS - 0.05, CFG))
			expect(nearly.state).to.equal(Pads.FILLING)
		end)

		it("hands the party over exactly ONCE, at the deadline and not a frame before", function()
			local pad = select(1, Pads.withSize(select(1, Pads.step(Pads.empty(3), who(11), 1, CFG)), 2, 1.2, CFG))
			local full = select(1, Pads.step(pad, who(11, 22), 2, CFG))
			expect(full.state).to.equal(Pads.COUNTDOWN)
			-- `>=` AT THE DEADLINE: five seconds means five, not five-and-a-frame.
			local held = select(1, Pads.step(full, who(11, 22), (full.deadline :: number) - 0.01, CFG))
			expect(held.state).to.equal(Pads.COUNTDOWN)
			local gone, verdict = Pads.step(full, who(11, 22), full.deadline :: number, CFG)
			expect(verdict).to.equal(Pads.DEPART)
			expect(gone.state).to.equal(Pads.LEAVING)
			expect(#gone.members).to.equal(2)
			-- IN PRODUCTION THE LIST EMPTIES THE MOMENT THE DRIVE HAS THEM -- the owner leaves a man it
			-- has out of the member list -- and THAT is what takes the pad back to `empty` with no
			-- second `DEPART`.
			expect(select(1, Pads.step(gone, {}, 99, CFG)).state).to.equal(Pads.EMPTY)
		end)

		it("ASKS AGAIN when the hand-over failed, instead of stranding the party on a dead pad", function()
			-- STILL STANDING THERE ON THE NEXT SCAN MEANS THE DRIVE DID NOT TAKE THEM. `Lobby.depart`
			-- returns 0 whenever the injected seam throws or `world.enrol` refuses -- `Match.enrol`
			-- refuses a player it has never registered, *"Refused rather than half-done"* -- and
			-- without this the pad would sit in `leaving` with its `DHPadState` on the part, no
			-- dialog, no countdown and no second attempt, until the man happened to walk off the
			-- rectangle. That is the one state in this machine a player cannot get himself out of.
			--
			-- THE REVIEWER FOUND THIS IN ROUND 1: the design's own transition table said the pad
			-- re-enters `sizing`, two comments claimed it did, and the code returned `NONE` for ever.
			local pad = select(1, Pads.withSize(select(1, Pads.step(Pads.empty(2), who(11), 1, CFG)), 2, 1.2, CFG))
			local full = select(1, Pads.step(pad, who(11, 22), 2, CFG))
			local stuck = select(1, Pads.step(full, who(11, 22), full.deadline :: number, CFG))
			expect(stuck.state).to.equal(Pads.LEAVING)

			local retry, verdict = Pads.step(stuck, who(11, 22), (full.deadline :: number) + 0.1, CFG)
			expect(verdict).to.equal(Pads.ASK)
			expect(retry.state).to.equal(Pads.SIZING)
			-- A FRESH QUESTION AND NOT A RESUMED ONE: the size is dropped and the pick clock starts
			-- again, which is `Join.decide`'s rule read at the level of the pad.
			expect(retry.size).to.equal(nil)
			expect(retry.firstUserId).to.equal(11)
			expect(retry.deadline).to.equal((full.deadline :: number) + 0.1 + PADS.PICK_TIMEOUT_SECONDS)
			-- ...AND IT DOES NOT DEPART AGAIN ON THE WAY OUT: one `DEPART` per countdown, and the
			-- retry has to go round the whole machine to earn the next one.
			expect(verdict).never.to.equal(Pads.DEPART)
			-- THE RETRY REACHES THE DRIVE BY ITSELF, with nobody pressing anything.
			local at = (full.deadline :: number) + 0.1
			local sawDepart = false
			local walking = retry
			while at < (full.deadline :: number) + PADS.PICK_TIMEOUT_SECONDS + CFG.COUNTDOWN_SECONDS + 1 do
				at += 1 / CFG.SCAN_HZ
				local verdictAgain
				walking, verdictAgain = Pads.step(walking, who(11, 22), at, CFG)
				if verdictAgain == Pads.DEPART then
					sawDepart = true
				end
			end
			expect(sawDepart).to.equal(true)
		end)

		it("cancels when the pad EMPTIES, and a re-entry inherits nothing", function()
			local pad = select(1, Pads.withSize(select(1, Pads.step(Pads.empty(1), who(11), 1, CFG)), 8, 1.2, CFG))
			expect(pad.size).to.equal(8)
			local gone, verdict = Pads.step(pad, {}, 2, CFG)
			expect(verdict).to.equal(Pads.CANCELLED)
			expect(gone.state).to.equal(Pads.EMPTY)
			-- KAREN'S RULE, AND IT IS `Join.decide`'S WORD FOR WORD: a cancel that kept the size
			-- would make stepping out and back in a pause nobody asked for.
			expect(gone.size).to.equal(nil)
			expect(gone.firstUserId).to.equal(nil)
			expect(gone.deadline).to.equal(nil)
			expect(#gone.members).to.equal(0)
			local back, again = Pads.step(gone, who(11), 3, CFG)
			expect(again).to.equal(Pads.ASK)
			expect(back.size).to.equal(nil)
			expect(back.deadline).to.equal(3 + PADS.PICK_TIMEOUT_SECONDS)
		end)

		it("re-elects with a FRESH clock when the first man steps off mid-dialog", function()
			local pad = select(1, Pads.step(Pads.empty(1), who(11, 22), 1, CFG))
			expect(pad.firstUserId).to.equal(11)
			local after, verdict = Pads.step(pad, { { userId = 22, since = 1 } }, 1.5, CFG)
			-- THE PAD DOES NOT CANCEL WHILE ANYBODY IS ON IT: a pad that cancelled would throw away
			-- three men because the fourth walked away. It is a QUESTION and not an inheritance --
			-- `size` is still nil and the clock starts again.
			expect(verdict).to.equal(Pads.ASK)
			expect(after.firstUserId).to.equal(22)
			expect(after.size).to.equal(nil)
			expect(after.deadline).to.equal(1.5 + PADS.PICK_TIMEOUT_SECONDS)
		end)

		it("does NOT cancel or move the countdown when somebody joins or leaves it", function()
			-- TWO JUDGEMENT CALLS, ASSERTED SO THEY ARE DECISIONS AND NOT ACCIDENTS. The countdown
			-- belongs to the PAD, so (a) a party of four that loses one at second four still goes,
			-- and (b) a late arrival cannot push back a clock somebody else is watching. Only an
			-- EMPTY pad cancels.
			local pad = select(1, Pads.withSize(select(1, Pads.step(Pads.empty(1), who(11), 1, CFG)), 4, 1.2, CFG))
			local full = select(1, Pads.step(pad, who(11, 22, 33, 44), 2, CFG))
			expect(full.state).to.equal(Pads.COUNTDOWN)
			local thinner = select(1, Pads.step(full, who(11, 22), 2.5, CFG))
			expect(thinner.state).to.equal(Pads.COUNTDOWN)
			expect(thinner.deadline).to.equal(full.deadline)
			local fatter = select(1, Pads.step(full, who(11, 22, 33, 44, 55), 2.5, CFG))
			expect(fatter.deadline).to.equal(full.deadline)
			expect(#fatter.members).to.equal(5)
			-- ...AND THE LAST MAN OFF STILL CANCELS IT, with nobody enrolled.
			local empty, cancelled = Pads.step(full, {}, 2.6, CFG)
			expect(cancelled).to.equal(Pads.CANCELLED)
			expect(empty.state).to.equal(Pads.EMPTY)
		end)

		it("says what the board says, for every state", function()
			local words = PADS.BILLBOARD
			local function board(pad)
				return select(2, Pads.labelFor(pad, CFG))
			end
			local idle = Pads.empty(3)
			expect(select(1, Pads.labelFor(idle, CFG))).to.equal("TRUCK 3")
			-- `0 / -` AND NOT `0 / 0`: nobody having picked yet is not a party of nought.
			expect(board(idle)).to.equal(string.format(words.COUNT_UNSET, 0))
			local sizing = select(1, Pads.step(Pads.empty(3), who(11), 1, CFG))
			expect(board(sizing)).to.equal(string.format(words.COUNT_UNSET, 1))
			local filling = select(1, Pads.withSize(sizing, 4, 1.2, CFG))
			-- KAREN'S OWN FORMAT: *"can be 1/1 or 4/4"*.
			expect(board(select(1, Pads.step(filling, who(11, 22), 2, CFG)))).to.equal("2 / 4")
		end)

		it("offers the sizes Karen asked for, and the biggest one IS the drive's whole roster", function()
			expect(PADS.SIZES[1].size).to.equal(1)
			local biggest = PADS.SIZES[#PADS.SIZES].size
			-- 8 = 4 HUNTERS + 4 BEATERS, asserted against the DRIVE's own table and never a copy of
			-- the number: a party of eight has to BE the whole hunt, or *"full hunt"* on the button
			-- is a lie. Bots fill every slot no player takes (task 161), which is what makes a party
			-- of one today's game exactly.
			local target = Match.CONFIG.BOTS.TARGET
			expect(biggest).to.equal(target.hunters + target.beaters)
			-- IN ORDER, WHOLE, AND NONE BIGGER THAN THE DRIVE, so the dialog reads 1, 2, 4, 8 down
			-- the panel and row 1 is the default a pick nobody makes falls back to.
			local last = 0
			for _, row in ipairs(PADS.SIZES) do
				expect(row.size % 1).to.equal(0)
				expect(row.size > last).to.equal(true)
				expect(row.size <= biggest).to.equal(true)
				expect(type(row.label)).to.equal("string")
				-- THE LABEL CARRIES THE SIZE ITSELF, so a row whose words and number disagree fails
				-- here rather than on Karen's screen.
				expect(string.find(row.label, tostring(row.size), 1, true) ~= nil).to.equal(true)
				last = row.size
			end
		end)
	end)

	describe("who belongs back at the lodge", function()
		it("answers for all eight combinations", function()
			-- In the drive: never, whatever else is true -- the drive owns where he stands.
			expect(Join.needsReturn(true, true, true)).to.equal(false)
			expect(Join.needsReturn(true, true, false)).to.equal(false)
			expect(Join.needsReturn(true, false, true)).to.equal(false)
			expect(Join.needsReturn(true, false, false)).to.equal(false)
			-- HELD: never. During the results scene a dismissed player is 570 studs from the lodge,
			-- and without this the lobby would respawn him out of Karen's results scene.
			expect(Join.needsReturn(false, true, false)).to.equal(false)
			expect(Join.needsReturn(false, true, true)).to.equal(false)
			-- Out of the drive, not held, and standing on the field already: leave him alone.
			expect(Join.needsReturn(false, false, true)).to.equal(false)
			-- The one case that returns him.
			expect(Join.needsReturn(false, false, false)).to.equal(true)
		end)

		it("does nothing at all when there is no position: absent is not outside", function()
			expect(Join.needsReturn(false, false, nil)).to.equal(false)
			expect(Join.needsReturn(true, false, nil)).to.equal(false)
		end)

		it("reads the field as a rectangle and not as a circle", function()
			local anchor = Vector3.new(2850, 153, -2950)
			local half = CFG.FIELD.SPAN_STUDS / 2
			expect(Join.insideField(anchor, anchor, CFG)).to.equal(true)
			-- The corner of the yard is still the yard.
			expect(Join.insideField(anchor + Vector3.new(half - 1, 0, half - 1), anchor, CFG)).to.equal(true)
			expect(Join.insideField(anchor + Vector3.new(half + 1, 0, 0), anchor, CFG)).to.equal(false)
			expect(Join.insideField(anchor + Vector3.new(0, 0, -half - 1), anchor, CFG)).to.equal(false)
			-- Height is not bounded: the field is a footprint.
			expect(Join.insideField(anchor + Vector3.new(0, 400, 0), anchor, CFG)).to.equal(true)
		end)
	end)

	-- ---------------------------------------------------------------- the range (task 302)
	--
	-- MEASURED IN KAREN'S PLACE, 2026-10-28: a character placed on the range mat at (2650, 145,
	-- -3214) was respawned at the lodge (2850, 153, -2934) 0.6 s later -- the mat is 268 studs from
	-- the anchor and the field's half-span is 110, so she could not use the range at all.
	--
	-- EVERY NUMBER HERE IS READ, NOT TYPED: the lodge row out of `Lobby.ANCHORS`, the range row and
	-- its footprint out of `Range`. The old predicate (`Join.insideField`) is evaluated BESIDE the
	-- new one on the same points, so each case shows the flip it is claiming and cannot pass
	-- against a reader that answers the same thing either way (L-093).
	describe("the range and the walk to it are part of the lobby (task 302)", function()
		local RangeData = require(ReplicatedStorage:WaitForChild("Range"))
		local LODGE = Data.anchorFor("forest-test") :: any
		local ROW = RangeData.anchorFor("forest-test") :: any
		local anchor = Vector3.new(LODGE.x, 0, LODGE.z)
		local rangeAnchor = Vector3.new(ROW.x, 0, ROW.z)

		-- THE UNION IS BUILT INSIDE EACH CASE, not once in this `describe`. At the base commit
		-- neither `Range.footprintFor` nor `Join.homeAreas` exists, and a describe-level call would
		-- take the whole FILE down as one error instead of failing the four cases that claim
		-- something (V293b: a FAIL FIRST line names the case it covers).
		local function union()
			local footprint = RangeData.footprintFor(rangeAnchor, RangeData.LAYOUT, RangeData.downrangeOf(ROW))
			return Join.homeAreas(anchor, CFG, { footprint }), footprint
		end

		-- THE TWO READERS, SIDE BY SIDE. `was` is the shipped rule before this task; `now` is the
		-- one this task writes. Neither is a constant: both run over the same position.
		local function was(at: Vector3): boolean
			return Join.needsReturn(false, false, Join.insideField(at, anchor, CFG))
		end
		local function nowAt(at: Vector3, areas): boolean
			return Join.needsReturn(false, false, Join.insideHome(at, areas))
		end

		it("leaves a man on the mat, on the firing line, and all the way there, where he is", function()
			local areas = union()
			local mat = RangeData.matPosition(rangeAnchor, 1, RangeData.LAYOUT)
			local dir = RangeData.downrangeOf(ROW)
			-- THE FIRING LINE: the mat's own downrange edge, where a man stands to shoot.
			local line = mat + Vector3.new(0, 0, dir * RangeData.LAYOUT.MAT.size.Z / 2)
			local points = { { "mat", mat }, { "firing line", line } }
			-- THREE POINTS ALONG THE WALK, on the straight line from the lodge anchor to the mat.
			for _, t in ipairs({ 0.25, 0.5, 0.75 }) do
				table.insert(points, { string.format("walk t=%.2f", t), anchor:Lerp(mat, t) })
			end
			-- ...AND EVERY OTHER STATION'S MAT (task 315). Since the range moved straight out of the
			-- shop door the walk is SHORT and STRAIGHT, so all three `t` points above now fall
			-- inside the lobby field's own 220 x 220 -- which is the move working, not the rule
			-- failing, and it took the bite below from 3 of 5 to 2 of 5. The six mats are the
			-- points that genuinely need the new rule, so they are the ones this case carries.
			for spot = 2, RangeData.LAYOUT.SPOT_COUNT do
				table.insert(points, {
					string.format("mat %d", spot),
					RangeData.matPosition(rangeAnchor, spot, RangeData.LAYOUT),
				})
			end
			local flipped = {}
			for _, row in ipairs(points) do
				local name, at = row[1], row[2] :: Vector3
				expect(nowAt(at, areas)).to.equal(false, string.format("%s: still sent back to the lodge", name))
				if was(at) then
					table.insert(flipped, name)
				end
			end
			-- THE BITE: most of these points ARE returned by the shipped rule, so this case fails
			-- at the base commit rather than passing for free (L-093).
			expect(#flipped >= 3).to.equal(
				true,
				string.format("only %d of %d points changed answer", #flipped, #points)
			)
			TestKit.note(
				string.format(
					"task 302: %d of %d range points were returned by the old field rule and are home now (%s)",
					#flipped,
					#points,
					table.concat(flipped, ", ")
				)
			)
		end)

		it("sends him back the moment he steps off ANY of the three rectangles", function()
			-- ONE CASE PER SUB-BOUNDARY (L-093): the midpoint of each of the twelve edges, pushed
			-- one stud out. A point that lands inside another rectangle is an interior seam and is
			-- skipped -- and the number actually asserted is printed, so a run that skipped them
			-- all could not read as a pass.
			local areas = union()
			local tested = 0
			local perRect = {}
			for index, rect in ipairs(areas) do
				local midX = (rect.minX + rect.maxX) / 2
				local midZ = (rect.minZ + rect.maxZ) / 2
				local outs = {
					Vector3.new(rect.minX - 1, 0, midZ),
					Vector3.new(rect.maxX + 1, 0, midZ),
					Vector3.new(midX, 0, rect.minZ - 1),
					Vector3.new(midX, 0, rect.maxZ + 1),
				}
				local here = 0
				for _, at in ipairs(outs) do
					if not Join.insideHome(at, areas) then
						expect(nowAt(at, areas)).to.equal(
							true,
							string.format(
								"rectangle %d: %s is outside the lobby and was not returned",
								index,
								tostring(at)
							)
						)
						here += 1
						tested += 1
					end
				end
				-- EVERY RECTANGLE DOES SOMETHING: it either contributes a BOUNDARY of the union (a
				-- point one stud off one of its edges that no other rectangle covers), or it contributes
				-- GROUND of its own. Round 1's `expect(here > 0)` asked only the first, and since task
				-- 306 B8 put the range beside the lodge, `Join.walkwayTo`'s corridor answers no to it --
				-- all four of its edge midpoints fall inside the field or the range footprint.
				--
				-- TWO WEAKER REPLACEMENTS WERE WRITTEN AND BOTH WERE TAUTOLOGIES, so the trap is named:
				-- re-asking `Join.insideHome(at, areas)` for `at` in `outs` asserts this loop's own exit
				-- condition (review round 1, finding 1), and asking it of `others` is the SAME question
				-- -- every point in `outs` lies outside rectangle `index` by construction, so that
				-- rectangle can never be the one covering it.
				--
				-- AND THE THIRD VERSION, "the others cover its whole area", was MEASURED FALSE on the
				-- first run (`lobby.spec:1048`): the walkway is not redundant, it carries ground the
				-- field and the footprint do not. So the rule below is the one that is both true and
				-- able to fail -- a rectangle that contributed neither a boundary nor one stud of its
				-- own ground would be a rectangle with no reason to exist, and this reddens on it.
				if here == 0 then
					local others = {}
					for otherIndex, other in ipairs(areas) do
						if otherIndex ~= index then
							table.insert(others, other)
						end
					end
					expect(#others).to.equal(#areas - 1)
					local own, first = 0, nil
					for ix = 0, 4 do
						for iz = 0, 4 do
							local at = Vector3.new(
								rect.minX + (rect.maxX - rect.minX) * ix / 4,
								0,
								rect.minZ + (rect.maxZ - rect.minZ) * iz / 4
							)
							expect(Join.insideHome(at, areas)).to.equal(true)
							if not Join.insideHome(at, others) then
								own += 1
								first = first or at
							end
						end
					end
					-- TASK 315 MEASURED THE THIRD VERSION TRUE AT LAST, and the assertion is the
					-- OPPOSITE of the one that stood here. With the range straight out of the shop
					-- door the field and the footprint MEET on z -3060..-3057, so the walkway
					-- between them carries no ground of its own any more: a rectangle with no
					-- boundary sample is now WHOLLY redundant, and this says so.
					--
					-- IT IS FALSIFIABLE AND IT WOULD HAVE REDDENED AT THE BASE COMMIT, which is the
					-- whole reason it is written this way (round 1, finding 1): at d4b10eda the
					-- walkway had `here == 0` AND `own > 0`, so `own == 0` was FALSE. Re-asserting
					-- `insideHome(at, others)` under `if own == 0` -- the first draft -- restated
					-- the guard it sat under and could not fail.
					expect(own).to.equal(
						0,
						string.format(
							"rectangle %d has no boundary sample yet carries %d of 25 points of its own ground -- it is neither an edge case nor redundant",
							index,
							own
						)
					)
					table.insert(
						perRect,
						string.format("rect %d: no edge, %d of 25 own points (first %s)", index, own, tostring(first))
					)
				end
				table.insert(perRect, string.format("rect %d: %d", index, here))
				-- ...and ON the edge is IN, which is `withinRect`'s rule in min/max form.
				expect(Join.withinArea(Vector3.new(rect.minX, 0, rect.minZ), rect)).to.equal(true)
				expect(Join.withinArea(Vector3.new(rect.maxX, 0, rect.maxZ), rect)).to.equal(true)
				-- FLAT: 400 studs up is still inside.
				expect(Join.withinArea(Vector3.new(midX, 400, midZ), rect)).to.equal(true)
			end
			expect(tested >= 3).to.equal(true)
			TestKit.note(
				string.format(
					"task 302: %d outside-the-edge cases returned him (%s)",
					tested,
					table.concat(perRect, ", ")
				)
			)
		end)

		it("is EXACTLY the old 220 x 220 square in a world with no range row", function()
			-- THE SWITCH-OFF CASE. `Lobby.start` hands `world.homeAreas` straight through, and a
			-- world with no range row (the DEV place, or the RANGE flag off) hands nil.
			local areas = union()
			local plain = Join.homeAreas(anchor, CFG, nil)
			expect(#plain).to.equal(1)
			local half = CFG.FIELD.SPAN_STUDS / 2
			expect(plain[1].minX).to.equal(anchor.X - half)
			expect(plain[1].maxX).to.equal(anchor.X + half)
			expect(plain[1].minZ).to.equal(anchor.Z - half)
			expect(plain[1].maxZ).to.equal(anchor.Z + half)
			-- ...and the two predicates agree on every point of a grid that straddles all four
			-- edges, which is the claim "bit for bit" actually means (L-151). The count is printed.
			local checked, disagreed = 0, 0
			for dx = -200, 200, 10 do
				for dz = -200, 200, 10 do
					local at = anchor + Vector3.new(dx, 0, dz)
					checked += 1
					if Join.insideHome(at, plain) ~= Join.insideField(at, anchor, CFG) then
						disagreed += 1
					end
				end
			end
			expect(disagreed).to.equal(0)
			expect(checked).to.equal(41 * 41)
			-- THE SAME GRID AGAINST THE RANGE LIST DOES NOT AGREE, so the grid is a real instrument
			-- and not one that would report 0 whatever it was handed.
			local differs = 0
			for dx = -200, 200, 10 do
				for dz = -600, 200, 10 do
					local at = anchor + Vector3.new(dx, 0, dz)
					if Join.insideHome(at, areas) ~= Join.insideField(at, anchor, CFG) then
						differs += 1
					end
				end
			end
			expect(differs > 0).to.equal(true)
			TestKit.note(
				string.format(
					"task 302: no-range grid %d points, %d disagreements; with the range, %d points differ",
					checked,
					disagreed,
					differs
				)
			)
		end)

		it("still never touches a man in the drive, a man held, or a man with no position", function()
			local areas, footprint = union()
			local mat = RangeData.matPosition(rangeAnchor, 1, RangeData.LAYOUT)
			local far = Vector3.new(footprint.minX - 400, 0, footprint.minZ - 400)
			-- The arm that proves `far` is a real outside point.
			expect(nowAt(far, areas)).to.equal(true)
			for _, at in ipairs({ mat, far }) do
				local inside = Join.insideHome(at, areas)
				expect(Join.needsReturn(true, false, inside)).to.equal(false)
				expect(Join.needsReturn(true, true, inside)).to.equal(false)
				expect(Join.needsReturn(false, true, inside)).to.equal(false)
			end
			-- Absent is not outside, at the range as anywhere else.
			expect(Join.needsReturn(false, false, nil)).to.equal(false)
		end)
	end)

	describe("the field, cut and filled", function()
		local anchor = Vector3.new(2850, 0, -2950)
		local shelf = 153

		it("puts the grass block's top AT the shelf and its bottom below the lowest ground", function()
			local at, size = Field.grassBlock(anchor, shelf, CFG)
			expect(size.X).to.equal(CFG.FIELD.SPAN_STUDS)
			expect(size.Z).to.equal(CFG.FIELD.SPAN_STUDS)
			expect(size.Y).to.equal(CFG.FIELD.DEPTH_STUDS)
			expect(at.Position.Y + size.Y / 2).to.equal(shelf)
			-- 48 studs reaches below the worst of the fifteen sampled footprints (44 studs of spread),
			-- so the slab meets undisturbed ground on every corner rather than floating.
			expect(CFG.FIELD.DEPTH_STUDS > 44).to.equal(true)
		end)

		it("starts the air block on the VOXEL BOUNDARY below the shelf, and clears the ridge", function()
			-- TASK 311, AND THIS ASSERTION USED TO SAY "AT the shelf". That was the mound: measured
			-- in Karen's place, 1.27 studs of relief under truck bays 2 and 3 and Truck4's whole body
			-- 1.27 studs higher than Truck1's. `FillBlock` writes 4-stud voxels, so an air box whose
			-- bottom lands INSIDE a voxel writes that voxel only partly and the hill's own occupancy
			-- survives in it. On the boundary it is covered whole and comes out empty.
			local at, size = Field.airBlock(anchor, shelf, CFG)
			local bottom = at.Position.Y - size.Y / 2
			expect(bottom).to.equal(Field.cutBottomY(shelf))
			expect(bottom % Field.RESOLUTION).to.equal(0)
			expect(bottom <= shelf).to.equal(true)
			expect(shelf - bottom < Field.RESOLUTION).to.equal(true)
			-- IT STILL REACHES `CLEAR_STUDS` ABOVE THE SHELF: the box grew downwards, not upwards.
			expect(at.Position.Y + size.Y / 2).to.equal(shelf + CFG.FIELD.CLEAR_STUDS)
			-- Above the ridge, so the lodge is never built inside the hill it just cut.
			expect(CFG.FIELD.CLEAR_STUDS > CFG.LODGE.RIDGE_STUDS).to.equal(true)
		end)

		it("snaps a measured shelf onto the voxel grid, by at most half a voxel", function()
			-- CYCLE 2 OF TASK 311, AND IT IS THE MEASUREMENT THAT ASKED FOR IT. Cutting on the
			-- boundary made all four bays identical (relief 1.27 -> 0.00) and then settled the
			-- surface at 151.27 against a shelf of 149.248 -- flat, and 1.5 studs over the road
			-- slabs, which is task 180's invisible road again. A shelf ON the grid has no partial
			-- voxel for the engine to interpolate.
			for _, measured in ipairs({ 149.248, 150.36, 151.27, 148, 152, 0, -3.1 }) do
				local snapped = Field.shelfFor(measured)
				expect(snapped % Field.RESOLUTION).to.equal(0)
				-- FLOOR: never above the measured ground, and never more than a voxel below it.
				expect(snapped <= measured + 1e-9).to.equal(true)
				expect(measured - snapped < Field.RESOLUTION).to.equal(true)
				-- ...AND THEN THE CUT IS THE SHELF ITSELF: no voxel is split by any of the fills.
				expect(Field.cutBottomY(snapped)).to.equal(snapped)
				local at, size = Field.airBlock(anchor, snapped, CFG)
				expect(at.Position.Y - size.Y / 2).to.equal(snapped)
				expect(size.Y).to.equal(CFG.FIELD.CLEAR_STUDS)
				local grassAt, grassSize = Field.grassBlock(anchor, snapped, CFG)
				expect(grassAt.Position.Y + grassSize.Y / 2).to.equal(snapped)
			end
			-- A SHELF ALREADY ON THE GRID DOES NOT MOVE.
			expect(Field.shelfFor(148)).to.equal(148)
		end)

		it("snaps to the SAME cut on a second build, fed the surface the first one produced", function()
			-- REVIEW ROUND 1, FINDING 1, AND IT IS A REAL RETRY PATH: `Build.defaultRigSource` yields
			-- and a build that throws is retried by `Lobby.step`, so the second `tryBuild` reads the
			-- ground the FIRST fill produced -- which this task measured at two studs above the cut.
			-- With `math.round` a cut of 148 produced 150, `round(150 / 4) = 38` cut at 152, the next
			-- at 156, and every retry lifted the whole lobby a voxel. The snap must be a FIXED POINT
			-- under that feedback.
			--
			-- THE SURFACE IS THE INSTRUMENT'S OWN NUMBER: +2 is what `p311-after3.txt` read in her
			-- place for a cut at 148, and the loop below also tries the neighbouring offsets so the
			-- property does not rest on that one measurement.
			for _, measured in ipairs({ 149.248, 150.36, 151.27, 147.5, 152.9 }) do
				local first = Field.shelfFor(measured)
				for _, produced in ipairs({ first + 2, first + 1, first + 3.9, first }) do
					expect(Field.shelfFor(produced)).to.equal(first)
				end
			end
		end)

		it("cuts the band for a shelf anywhere in a voxel, and never cuts below one", function()
			-- EVERY POSITION INSIDE A VOXEL, including both boundaries, because the live shelf is
			-- 149.248 and a spec that only ever tried 153 would not have caught the old bug either.
			for _, y in ipairs({ 148, 149.248, 150, 151.9999, 152, -3.5, 0 }) do
				local cut = Field.cutBottomY(y)
				expect(cut % Field.RESOLUTION).to.equal(0)
				expect(cut <= y).to.equal(true)
				expect(y - cut < Field.RESOLUTION).to.equal(true)
			end
			-- A SHELF ALREADY ON A BOUNDARY MUST NOT MOVE THE BOX DOWN A WHOLE VOXEL: that would eat
			-- a voxel of the shelf the grass block is about to lay.
			expect(Field.cutBottomY(152)).to.equal(152)
		end)

		it("fills air BEFORE grass, because the air box now reaches below the shelf", function()
			-- THE ORDER IS PART OF THE FIX AND NOT A STYLE: an air box whose bottom is under the
			-- shelf, run last, would cut a hole in the grass it is meant to leave. A recording fake,
			-- so no spec ever writes a place's terrain (`Field.luau`'s own rule).
			local order = {}
			local fake = {
				FillBlock = function(_self, _at, _size, material)
					table.insert(order, material)
				end,
				ReplaceMaterial = function() end,
			}
			Field.fill(fake, anchor, shelf, CFG)
			expect(#order > 2).to.equal(true)
			expect(order[1]).to.equal(Enum.Material.Air)
			-- NO AIR AFTER THE FIRST RUN OF IT: once the grass starts, nothing may cut again.
			local sawGround = false
			for _, material in ipairs(order) do
				if material ~= Enum.Material.Air then
					sawGround = true
				elseif sawGround then
					expect("air was filled after the grass").to.equal(false)
				end
			end
			expect(sawGround).to.equal(true)
		end)

		it("lays pads of a material with no grass blades under the buildings AND the road", function()
			-- BOTH OF THESE WERE PHOTOGRAPHED RATHER THAN GUESSED. Task 177's inside shot came back
			-- with terrain grass growing through the lodge's floorboards; task 180's first road shot
			-- came back with a field and NO ROAD, with the player standing on it. One cause: a grass
			-- material draws its blades on the terrain surface and a part laid over them does not
			-- hide them.
			local covered = {
				anchor + CFG.LODGE.OFFSET,
				anchor + CFG.LODGE.OFFSET - Vector3.new(0, 0, CFG.LODGE.SIZE.Z / 2 + CFG.LODGE.PORCH.DEPTH),
				-- TASK 182: all four truck pads, which is what the yard has had to cover since the
				-- circle became four rectangles behind the bays.
				Pads.centreFor(anchor, 1, CFG),
				Pads.centreFor(anchor, CFG.TRUCK.COUNT, CFG),
				anchor + CFG.SPAWN.OFFSET,
				-- THE FAR TRUCK BAY, which the 80 x 60 yard of task 177 did not reach -- and since
				-- task 243 the bays step SOUTH and the parked body stands `BACK_STUDS` EAST, so this
				-- is the far corner of the block in BOTH directions at once.
				anchor
					+ CFG.TRUCK.OFFSET
					+ Vector3.new(CFG.TRUCK.BACK_STUDS, 0, -(CFG.TRUCK.COUNT - 1) * CFG.TRUCK.BAY_GAP_STUDS),
				-- both ends of the road, on its centre line
				Vector3.new(anchor.X + CFG.ROAD.CENTRE_X, 0, anchor.Z + CFG.ROAD.FROM_Z - 1),
				Vector3.new(anchor.X + CFG.ROAD.CENTRE_X, 0, anchor.Z + CFG.ROAD.TO_Z + 1),
				-- and its outer verge, which is the edge the blades came through
				Vector3.new(
					anchor.X + CFG.ROAD.CENTRE_X + CFG.ROAD.WIDTH_STUDS / 2 + CFG.ROAD.VERGE_STUDS,
					0,
					anchor.Z
				),
			}
			for _, point in ipairs(covered) do
				local found = false
				for _, pad in ipairs(CFG.FIELD.PADS) do
					local at, size = Field.padBlock(anchor, shelf, pad)
					expect(at.Position.Y + size.Y / 2).to.equal(shelf)
					expect(pad.MATERIAL).never.to.equal(CFG.FIELD.MATERIAL)
					if
						math.abs(point.X - at.Position.X) <= size.X / 2
						and math.abs(point.Z - at.Position.Z) <= size.Z / 2
					then
						found = true
					end
				end
				expect(found).to.equal(true)
			end
		end)

		it("writes nothing outside the field's own rectangle", function()
			-- EVERY PAD IN THE LIST AND NOT THE FIRST TWO BY INDEX (task 191). It was written as
			-- `PADS[1]` and `PADS[2]`, so the third pad this task adds -- and every pad after it --
			-- would have been outside the one audit that bounds them. A list the config calls a list
			-- is iterated.
			local blocks = {
				{ Field.grassBlock(anchor, shelf, CFG) },
				{ Field.airBlock(anchor, shelf, CFG) },
			}
			for _, pad in ipairs(CFG.FIELD.PADS) do
				table.insert(blocks, { Field.padBlock(anchor, shelf, pad) })
			end
			expect(#blocks).to.equal(2 + #CFG.FIELD.PADS)
			for _, block in ipairs(blocks) do
				local at, size = block[1] :: CFrame, block[2] :: Vector3
				expect(Field.insideField(anchor, at, size, CFG)).to.equal(true)
				for _, point in ipairs(corners(at, size)) do
					local half = CFG.FIELD.SPAN_STUDS / 2
					expect(math.abs(point.X - anchor.X) <= half + 1e-6).to.equal(true)
					expect(math.abs(point.Z - anchor.Z) <= half + 1e-6).to.equal(true)
				end
			end
		end)

		it("chunks a wide box and leaves a narrow one alone", function()
			local at, size = Field.grassBlock(anchor, shelf, CFG)
			local whole = Field.chunks(at, size, 1000)
			expect(#whole).to.equal(1)
			expect(whole[1].size.X).to.equal(size.X)

			local pieces = Field.chunks(at, size, CFG.FIELD.CHUNK_STUDS)
			expect(#pieces > 1).to.equal(true)
			-- Every chunk is inside the rectangle, and together they cover it exactly.
			local total = 0
			for _, piece in ipairs(pieces) do
				total += piece.size.X
				expect(piece.size.X <= CFG.FIELD.CHUNK_STUDS + 1e-6).to.equal(true)
				expect(Field.insideField(anchor, piece.at, piece.size, CFG)).to.equal(true)
			end
			expect(math.abs(total - size.X) < 1e-6).to.equal(true)
		end)

		it("cuts AIR first and then fills, through the argument and never through Workspace", function()
			local fake = fakeTerrain()
			local calls, grassCalls = Field.fill(fake, anchor, shelf, CFG)
			expect(calls).to.equal(#fake.calls)
			expect(grassCalls > 0).to.equal(true)
			expect(calls > grassCalls).to.equal(true)
			-- AIR FIRST SINCE TASK 311, and the order is the fix rather than a style: the air box's
			-- bottom is now the voxel boundary BELOW the shelf -- which is what cuts the band the
			-- mound survived in -- so running it last would cut a hole in the grass it must leave.
			-- Then the grass up to the shelf, then the blade-free pads on top of it.
			expect(fake.calls[1].material).to.equal(Enum.Material.Air)
			expect(fake.calls[#fake.calls].material).to.equal(CFG.FIELD.PADS[1].MATERIAL)
			local seen = { grass = 0, pad = 0, air = 0 }
			for _, call in ipairs(fake.calls) do
				if call.material == Enum.Material.Air then
					seen.air += 1
					expect(seen.grass + seen.pad).to.equal(0) -- all the cutting happens first
				elseif call.material == CFG.FIELD.MATERIAL then
					seen.grass += 1
					expect(seen.pad).to.equal(0) -- ...then the grass
				else
					expect(call.material).to.equal(CFG.FIELD.PADS[1].MATERIAL)
					seen.pad += 1
				end
			end
			expect(seen.grass).to.equal(grassCalls)
			expect(seen.pad > 0).to.equal(true)
			expect(seen.air > 0).to.equal(true)
		end)

		-- ======================================================= TASK 244: A PAD IS ACTUALLY GRAVEL
		--
		-- KAREN, 2026-10-22, with a frame of the truck yard: *"move all trucks to right so it not
		-- going to be on grass"*.
		--
		-- MEASURED IN THE LIVE FOREST TEST BEFORE A LINE OF THIS WAS WRITTEN (rule H): a raycast
		-- grid 2.5 studs apart over the yard read `Ground` at exactly 150.00 and `Grass` at
		-- 150.36..151.27 in a DIAGONAL band across the bays -- a CONTOUR OF THE OLD HILL, inside the
		-- pad's own rectangle, which contains every truck with ~20 studs to spare. Under the four
		-- trucks' sixteen wheels: bay 1 none on grass, bay 2 one, bay 3 two, bay 4 ALL FOUR.
		--
		-- THE CAUSE IS THE VOXEL GRID, not the rectangle: the pad block's top IS the shelf and the
		-- shelf (149.248) falls inside the 148..152 voxel band, so the block writes only part of
		-- that voxel and the hill's grass keeps the voxel's MATERIAL. `PAD_SKIN_ABOVE_STUDS`' own
		-- comment carries the measurement and why filling higher is the wrong fix -- it was tried,
		-- and it lifted the whole yard 1.27 studs and buried the road.
		it("scrubs every pad's own rectangle back to its own material (task 244)", function()
			local fake = fakeTerrain()
			local calls, _grassCalls, scrubbed = Field.fill(fake, anchor, shelf, CFG)
			expect(scrubbed).to.equal(#CFG.FIELD.PADS)
			expect(#fake.replacements).to.equal(scrubbed)
			expect(calls).to.equal(#fake.calls)
			for index, pad in ipairs(CFG.FIELD.PADS) do
				local done = fake.replacements[index]
				-- GRASS TO THE PAD'S OWN MATERIAL, and nothing else is touched: a rock or a path
				-- laid in this rectangle by anything else keeps what it is.
				expect(done.from).to.equal(CFG.FIELD.MATERIAL)
				expect(done.to).to.equal(pad.MATERIAL)
				-- THE ENGINE'S OWN RESOLUTION. `Terrain:ReplaceMaterial` takes 4 and nothing else,
				-- and `Places.Ground.RESOLUTION` is the same engine fact named in the one other
				-- system that calls this API -- so the duplication is CHECKED and not trusted.
				expect(done.resolution).to.equal(Field.RESOLUTION)
				expect(Field.RESOLUTION).to.equal(4)
				expect(Field.RESOLUTION).to.equal(Ground.RESOLUTION)
				local region = Field.padRegion(anchor, shelf, pad, CFG)
				expect(done.region.CFrame.Position).to.equal(region.CFrame.Position)
				expect(done.region.Size).to.equal(region.Size)
				-- IT IS THE PAD'S OWN FOOTPRINT, expanded OUTWARD to the grid -- the only direction
				-- that cannot leave a sliver of the pad unscrubbed.
				local centre = anchor + pad.OFFSET
				local min = region.CFrame.Position - region.Size / 2
				local max = region.CFrame.Position + region.Size / 2
				expect(min.X <= centre.X - pad.SIZE.X / 2).to.equal(true)
				expect(max.X >= centre.X + pad.SIZE.X / 2).to.equal(true)
				expect(min.Z <= centre.Z - pad.SIZE.Z / 2).to.equal(true)
				expect(max.Z >= centre.Z + pad.SIZE.Z / 2).to.equal(true)
				-- ...AND IT REACHES THE VOXEL BAND THE SHELF FALLS INSIDE, which is the whole point.
				expect(min.Y <= shelf - pad.SIZE.Y).to.equal(true)
				expect(max.Y >= shelf + CFG.FIELD.PAD_SKIN_ABOVE_STUDS).to.equal(true)
				-- EVERY EDGE ON THE 4-STUD GRID.
				for _, value in ipairs({ min.X, min.Y, min.Z, max.X, max.Y, max.Z }) do
					expect(value % 4).to.equal(0)
				end
				-- AND IT STAYS INSIDE THE FIELD, exactly as the three blocks do.
				expect(Field.insideField(anchor, region.CFrame, region.Size, CFG)).to.equal(true)
			end
			-- AFTER EVERY `FillBlock` AND NEVER BEFORE THEM: the air decides which voxels are there
			-- at all, and scrubbing first would scrub a hill that is about to be cut away. Since
			-- task 311 the LAST fill is a pad, not the air, so this is asserted on the fake's own
			-- two logs rather than on the last material.
			expect(#fake.replacements > 0).to.equal(true)
			expect(#fake.calls > 0).to.equal(true)
			-- EVERY TRUCK BAY IS INSIDE THE YARD PAD'S RECTANGLE, which is why the rectangle was
			-- never the problem and the material was. The bays run from the first to the last,
			-- `BAY_GAP_STUDS` apart, and the truck stands `BACK_STUDS` east of its bay centre.
			local yard = nil
			for _, pad in ipairs(CFG.FIELD.PADS) do
				if pad.NAME == "Yard" then
					yard = pad
				end
			end
			expect(yard).to.be.ok()
			local centre = anchor + (yard :: any).OFFSET
			local truck = CFG.TRUCK
			local half = truck.MODEL.LENGTH_STUDS / 2
			for bay = 0, truck.COUNT - 1 do
				local x = anchor.X + truck.OFFSET.X + truck.BACK_STUDS
				local z = anchor.Z + truck.OFFSET.Z - bay * truck.BAY_GAP_STUDS
				expect(x - half >= centre.X - (yard :: any).SIZE.X / 2).to.equal(true)
				expect(x + half <= centre.X + (yard :: any).SIZE.X / 2).to.equal(true)
				expect(z >= centre.Z - (yard :: any).SIZE.Z / 2).to.equal(true)
				expect(z <= centre.Z + (yard :: any).SIZE.Z / 2).to.equal(true)
			end
		end)
	end)

	-- TASK 191: THE GATHERING HAPPENS ON CLEAN GROUND, NEXT TO THE CABIN.
	--
	-- KAREN, 2026-10-15 ~17:20: *"next is when hunt over everyone is in clean ground no grass
	-- firstable / second it could be next to cabin"*. The end-of-drive gathering used to happen at
	-- the DRIVE's own spot in the forest, where tall grass hid the animals and the players; it
	-- happens in the lodge's own west yard now.
	--
	-- WHAT THIS BLOCK IS FOR: the rectangle is data, and every claim about it is arithmetic. Does the
	-- scene FIT in it (against `Match.CONFIG`, never against a copy)? Does it CLEAR everything the
	-- lobby already has? Is the ground under it BLADE-FREE? And is the spot's Y MEASURED rather than
	-- predicted, which is the fault that put four trucks' tyres underground in task 186?
	--
	-- Note: docs/research/2026-10-16-gathering-at-the-cabin.md
	describe("the gathering yard beside the cabin", function()
		local anchor = Vector3.new(2850, 149.248, -2950)
		local pad = Data.gatherPad(CFG)

		it("is one row in the pad list, found by name, with no grass blades on it", function()
			expect(pad).to.be.ok()
			expect((pad :: any).NAME).to.equal(CFG.GATHER.PAD_NAME)
			-- BLADE-FREE, which is the whole of Karen's *"clean ground no grass"*: Roblox draws a
			-- grass material's blades ON the terrain surface and nothing laid over them hides them,
			-- which this repo has photographed twice (the lodge's floorboards, and a road that was
			-- invisible). `FIELD.MATERIAL` is the grass; a pad is never it.
			expect((pad :: any).MATERIAL).to.never.equal(CFG.FIELD.MATERIAL)
			expect((pad :: any).MATERIAL).to.equal(Enum.Material.Ground)
			-- FOUND BY NAME AND NOT BY INDEX, so a fourth pad inserted anywhere in the list cannot
			-- silently become the gathering yard.
			expect(Data.gatherPad({ FIELD = { PADS = {} }, GATHER = CFG.GATHER })).to.equal(nil)
			expect(Data.gatherPad({
				FIELD = { PADS = { { NAME = "Yard" }, { NAME = "Road" } } },
				GATHER = CFG.GATHER,
			})).to.equal(nil)
		end)

		it("holds the WHOLE scene at its worst case, measured against Match's own numbers", function()
			-- THE SQUARE THE SCENE REALLY NEEDS, asked of the module that owns it: the bag is
			-- `MAX_ANIMALS`, `cornerReachFor` is where the four torches stand on both axes, and that
			-- already contains the ring (`ringRadiusFor`), which already contains the rows. So one
			-- number bounds every Instance and every body in the scene.
			local reach = Match.Scene.cornerReachFor(Match.CONFIG.SCENE.MAX_ANIMALS, Match.CONFIG)
			local size = (pad :: any).SIZE
			local margin = math.min(size.X, size.Z) / 2 - reach
			expect(reach > 0).to.equal(true)
			expect(margin > 0).to.equal(true)
			TestKit.note(
				string.format(
					"lobby: the gathering square is %.1f studs across (%d animals) inside a %.0f x %.0f yard"
						.. " -- %.1f studs of margin",
					reach * 2,
					Match.CONFIG.SCENE.MAX_ANIMALS,
					size.X,
					size.Z,
					margin
				)
			)
			-- ...AND THE RING OF PEOPLE IS INSIDE THE TORCHES, which is `Scene`'s own arithmetic and
			-- is asserted here because it is what makes the one bound above enough.
			expect(Match.Scene.ringRadiusFor(Match.CONFIG.SCENE.MAX_ANIMALS, Match.CONFIG) <= reach).to.equal(true)
		end)

		it("clears the lodge, the porch, the spawn, the road, the fences, the trucks and the four pads", function()
			local centre = anchor + (pad :: any).OFFSET
			local size = (pad :: any).SIZE
			local east = centre.X + size.X / 2
			-- WHAT HAS TO CLEAR THE BUILDING IS THE SCENE, NOT THE DIRT. The pad is a terrain
			-- material and nothing else -- east of the `Yard` pad's own west edge it repaints ground
			-- that is already blade-free -- so the clearance that matters is the square the TORCHES,
			-- the ring and the rows stand in, and it is `Scene.cornerReachFor` at the cap.
			local reach = Match.Scene.cornerReachFor(Match.CONFIG.SCENE.MAX_ANIMALS, Match.CONFIG)
			local lodgeWest = anchor.X + CFG.LODGE.OFFSET.X - CFG.LODGE.SIZE.X / 2
			local chimneyWest = lodgeWest - (CFG.LODGE.CHIMNEY.WIDTH - CFG.LODGE.CHIMNEY.INSET_STUDS)
			expect(centre.X + reach < chimneyWest).to.equal(true)
			-- ...and the PAD still stops short of the lodge's own footprint, so no part of the house
			-- stands on the gathering yard's dirt.
			expect(east < lodgeWest).to.equal(true)
			TestKit.note(
				string.format(
					"lobby: gathering square east edge %.1f | yard east edge %.1f | chimney %.1f | lodge wall %.1f",
					centre.X + reach,
					east,
					chimneyWest,
					lodgeWest
				)
			)
			-- EVERYTHING ELSE IN THE LOBBY IS EAST OF THE YARD, and that is one comparison each
			-- rather than a rectangle test, because the yard is a strip west of the whole layout.
			local roadWest = anchor.X + CFG.ROAD.CENTRE_X - CFG.ROAD.WIDTH_STUDS / 2 - CFG.ROAD.VERGE_STUDS
			local fenceWest = anchor.X + CFG.ROAD.CENTRE_X - CFG.FENCE.OFF_ROAD_STUDS
			local spawnWest = anchor.X + CFG.SPAWN.OFFSET.X - CFG.SPAWN.SIZE.X / 2 - 3 * CFG.SPAWN.SPREAD_STUDS
			-- The porch is the lodge less its inset on each side.
			local porchWest = lodgeWest + CFG.LODGE.PORCH.INSET_STUDS
			for what, edge in pairs({
				road = roadWest,
				fence = fenceWest,
				spawn = spawnWest,
				porch = porchWest,
			}) do
				expect(east < edge).to.equal(true)
				if east >= edge then
					TestKit.note(string.format("lobby: the gathering yard reaches the %s at %.1f", what, edge))
				end
			end
			-- THE FOUR TRUCK BAYS AND THE FOUR PADS, asked of `Pads.centreFor` -- the one place that
			-- arithmetic lives -- rather than re-derived here.
			for index = 1, CFG.TRUCK.COUNT do
				local at = Pads.centreFor(anchor, index, CFG)
				expect(east < at.X - CFG.PADS.SIZE.X / 2).to.equal(true)
				-- EVERY BAY SHARES ONE x SINCE TASK 243 -- the row steps south -- so this is the
				-- same bound four times, and it stays a loop because the thing being asserted is
				-- that NO bay is east of the gathering yard rather than that the first one is not.
				local bayX = anchor.X + CFG.TRUCK.OFFSET.X
				expect(east < bayX - CFG.TRUCK.MODEL.LENGTH_STUDS / 2).to.equal(true)
			end
		end)

		it("measures the spot's height and never predicts it", function()
			-- TASK 186'S FAULT, AND IT IS WHY THIS FUNCTION TAKES A READER AT ALL: `Field.fill`'s
			-- surface is NOT the nominal shelf -- Roblox terrain is voxelised, measured at 150.000
			-- against a shelf at 149.248 in this very yard -- and all four trucks had their tyres
			-- 0.752 studs underground because the arithmetic predicted the shelf.
			local asked = {}
			local at, facing = Data.gatherSpotFor(anchor, CFG, function(x, z)
				table.insert(asked, Vector2.new(x, z))
				return 150
			end)
			local centre = anchor + (pad :: any).OFFSET
			expect(at).to.be.ok()
			expect((at :: Vector3).X).to.equal(centre.X)
			expect((at :: Vector3).Z).to.equal(centre.Z)
			expect((at :: Vector3).Y).to.equal(150) -- the reader's answer, not the shelf's 149.248
			-- IT ASKS ABOUT THE YARD'S OWN CENTRE, once, and not about the anchor: the two are 52
			-- studs apart and the lodge's shelf is not this yard's surface.
			expect(#asked).to.equal(1)
			expect(asked[1]).to.equal(Vector2.new(centre.X, centre.Z))
			-- ...AND THE FACING IS THE CONFIG'S, +X, EAST AT THE LODGE (note section 5).
			expect(facing).to.equal(CFG.GATHER.FACING)
			expect(facing).to.equal(Vector3.new(1, 0, 0))
		end)

		it("falls back to the shelf for a reader that answers nothing, throws, or is not there", function()
			-- A DRIVE MUST NEVER LOSE KAREN'S SCENE TO A GROUND READER, which is the same rule
			-- `Match.displayAnimal` and `Body.groundUnder` already keep. The shelf is one stud of
			-- error at worst and `Scene.build` asks the reader AGAIN per animal and per torch (task
			-- 192), so a fallback spot is still a scene laid on the ground.
			local centre = anchor + (pad :: any).OFFSET
			for _, reader in ipairs({
				{ what = "no reader", fn = nil },
				{ what = "answers nothing", fn = function() end },
				{
					what = "answers a non-number",
					fn = function()
						return "up there"
					end,
				},
				{
					what = "throws",
					fn = function()
						error("no ground")
					end,
				},
			}) do
				local at, facing = Data.gatherSpotFor(anchor, CFG, (reader :: any).fn)
				expect(at).to.equal(Vector3.new(centre.X, anchor.Y, centre.Z))
				expect(facing).to.equal(CFG.GATHER.FACING)
			end
			-- AND A CONFIG WITH NO GATHERING YARD ANSWERS NOWHERE, both halves, so
			-- `Match.gatherSpotOf` falls through to the drive's own spot behind the stands.
			local none, noneFacing = Data.gatherSpotFor(anchor, {
				FIELD = { PADS = {} },
				GATHER = CFG.GATHER,
			}, nil)
			expect(none).to.equal(nil)
			expect(noneFacing).to.equal(nil)
		end)

		it("lets no tree stand on the gathering yard, and COUNTS the ones it takes out (task 261)", function()
			-- **UNTIL TASK 261 THIS CASE ASSERTED THE GUARD REMOVED NOTHING**, and that was true of a
			-- 56-stud yard at x -50: the western arc stands its trunks at x ~ -82 to -104
			-- (`RADIUS_STUDS` 100 with `JITTER_STUDS` 9) and the yard's west edge was -80, so the
			-- thirty FRAMED the gathering. The Director's decision of 2026-10-25 moved the yard to
			-- -62 and widened it to 80 x 80 so THIRTY animals fit in rows of six -- and a square that
			-- big reaches the arc.
			--
			-- SO THE CASE NOW ASSERTS THE TWO HALVES SEPARATELY, and only the first of them is a
			-- rule: NOTHING the live build plants may stand inside the rectangle (a spruce among the
			-- animals Karen asked to SEE is the same mistake as a spruce in the road), and HOW MANY
			-- the guard removed is a NUMBER -- reported, because it is what Karen looks at and not
			-- something arithmetic can settle.
			local centre = anchor + (pad :: any).OFFSET
			local size = (pad :: any).SIZE
			-- THE LIVE BUILD AND NOT THE NOMINAL ARC, because the jitter is what decides which trunks
			-- the exclusion can reach -- and it is seeded (`Random.new(1804)`), so this is an exact
			-- number and not a sample.
			local container = Instance.new("Folder")
			container.Name = "LobbySpecGatherTrees"
			container.Parent = Workspace
			local templates = fakeTemplates()
			local folder = Build.build(container, anchor, CFG, templates)
			local line = folder:FindFirstChild("TreeLine")
			expect(line).to.be.ok()
			local planted, onTheYard = 0, 0
			for _, tree in ipairs((line :: Instance):GetChildren()) do
				local at = if tree:IsA("BasePart")
					then (tree :: BasePart).Position
					else (tree :: Model):GetPivot().Position
				planted += 1
				if math.abs(at.X - centre.X) < size.X / 2 + 4 and math.abs(at.Z - centre.Z) < size.Z / 2 + 4 then
					onTheYard += 1
				end
			end
			container:Destroy()
			templates:Destroy()
			-- THE RULE: not one trunk on the gathering's ground.
			expect(onTheYard).to.equal(0)
			-- ...AND THE COUNT, which is what the move cost. The nominal bearings 23..28 land inside
			-- the new rectangle, so the arc loses six of its thirty to the clearing and keeps the
			-- rest -- and this number falling further is the thing to notice.
			expect(planted >= CFG.TREELINE.COUNT - 10).to.equal(true)
			TestKit.note(
				string.format(
					"lobby: the tree line plants %d of %d -- the gathering yard (%.0f x %.0f at x %.0f) is a clearing",
					planted,
					CFG.TREELINE.COUNT,
					size.X,
					size.Z,
					(pad :: any).OFFSET.X
				)
			)
			-- ...AND THE GUARD IS LOAD-BEARING NOW RATHER THAN SPARE: the nominal arc really does
			-- cross the rectangle, which is the fact that used to be false.
			local spec = CFG.TREELINE
			local span = spec.TO_RADIANS - spec.FROM_RADIANS
			local reaches = 0
			for index = 1, spec.COUNT do
				local angle = spec.FROM_RADIANS + span * ((index - 0.5) / spec.COUNT)
				local x = anchor.X + math.sin(angle) * spec.RADIUS_STUDS
				local z = anchor.Z + math.cos(angle) * spec.RADIUS_STUDS
				if math.abs(x - centre.X) < size.X / 2 + 4 and math.abs(z - centre.Z) < size.Z / 2 + 4 then
					reaches += 1
				end
			end
			expect(reaches).to.equal(6)
		end)

		it("keeps a spruce off the yard even if the arc is moved onto it", function()
			-- THE GUARD'S OWN TEST, and it needs a tree line that WOULD stand on the yard: the
			-- shipped arc cannot reach it, so a config whose radius is the yard's own distance is
			-- what makes the `continue` reachable at all. Without the guard, a spruce stands among
			-- Karen's animals.
			local container = Instance.new("Folder")
			container.Name = "LobbySpecGatherYard"
			container.Parent = Workspace
			local templates = fakeTemplates()
			local moved = table.clone(CFG) :: any
			moved.TREELINE = table.clone(CFG.TREELINE)
			-- Straight at the yard's centre, 52 studs west of the anchor, with the jitter turned off.
			moved.TREELINE.RADIUS_STUDS = math.abs((pad :: any).OFFSET.X)
			moved.TREELINE.JITTER_STUDS = 0
			moved.TREELINE.FROM_RADIANS = 4.6
			moved.TREELINE.TO_RADIANS = 5.2
			local folder = Build.build(container, anchor, moved, templates)
			local line = folder:FindFirstChild("TreeLine")
			local centre = anchor + (pad :: any).OFFSET
			local size = (pad :: any).SIZE
			local standing = 0
			if line ~= nil then
				for _, tree in ipairs((line :: Instance):GetChildren()) do
					local at = if tree:IsA("BasePart")
						then (tree :: BasePart).Position
						else (tree :: Model):GetPivot().Position
					if math.abs(at.X - centre.X) <= size.X / 2 and math.abs(at.Z - centre.Z) <= size.Z / 2 then
						standing += 1
					end
				end
			end
			expect(standing).to.equal(0)
			templates:Destroy()
			container:Destroy()
		end)
	end)

	describe("the parts build", function()
		local anchor = Vector3.new(0, 100, 0)
		local container, folder, count

		beforeEach(function()
			container = Instance.new("Folder")
			container.Name = "LobbySpecWorld"
			-- WORKSPACE AND NEVER A ROJO-OWNED CONTAINER: `ReplicatedStorage` is fully Rojo-owned with
			-- `$ignoreUnknownInstances: false`, so a folder parked there is DELETED at Karen's next
			-- Connect; `Workspace` is not mapped at all, which is the property `Workspace.Boars`,
			-- `Workspace.ForestMarkers` and `Workspace.WeaponEffects` already rely on. It is destroyed
			-- in `afterEach` either way.
			container.Parent = Workspace
			local made, _marker, _spawn, parts = Build.build(container, anchor, CFG)
			folder = made
			count = parts
		end)

		afterEach(function()
			container:Destroy()
		end)

		it("stays inside the part budget", function()
			expect(count <= CFG.MAX_PARTS).to.equal(true)
			expect(count > 50).to.equal(true) -- a lodge, a truck, a ring and a track is not five parts
		end)

		it("anchors everything, and the only things that collide are the shell", function()
			local collidable = {}
			for _, descendant in ipairs(folder:GetDescendants()) do
				if descendant:IsA("BasePart") then
					expect(descendant.Anchored).to.equal(true)
					if descendant.CanCollide then
						table.insert(collidable, descendant.Name)
					else
						-- `CanQuery = false` IS LOAD-BEARING: a slab that stops a pellet changes what
						-- the shot hit.
						expect(descendant.CanQuery).to.equal(false)
					end
				end
			end
			expect(#collidable > 0).to.equal(true)
			for _, name in ipairs(collidable) do
				local shell = string.match(name, "^Wall")
					or string.match(name, "^Roof")
					or string.match(name, "^Gable")
					or string.match(name, "^Floor")
					or string.match(name, "^WindowGlass")
					or string.match(name, "^Plinth")
					or string.match(name, "^Chimney")
					or string.match(name, "^Deck")
					or string.match(name, "^Porch")
					or string.match(name, "^DoorPost")
					or string.match(name, "^DoorLintel")
					or string.match(name, "^Fireplace")
					or string.match(name, "^Counter")
					or string.match(name, "^Table")
					or string.match(name, "^Bench")
					or string.match(name, "^SignPost")
					or string.match(name, "^Bed")
					or string.match(name, "^Cab")
					or string.match(name, "^Bonnet")
					or name == Data.SPAWN_NAME
				if shell == nil then
					error(string.format("a collidable part nothing meant to be solid: %s", name), 0)
				end
			end
		end)

		it("builds four named pads where the rule says, each untouchable and a different colour", function()
			-- THE DECK *IS* THE NAMED PART (task 182): there is no second invisible marker, so the
			-- part the rule reads, the part the client finds, the part the attributes live on and the
			-- thing Karen looks at are one instance and cannot drift apart.
			local seen: { [string]: boolean } = {}
			for index = 1, CFG.TRUCK.COUNT do
				local name = Data.padPartName(index) :: string
				local deck = folder:FindFirstChild(name, true)
				expect(deck).to.be.ok()
				local pad = deck :: BasePart
				local wanted = Pads.centreFor(anchor, index, CFG)
				expect((pad.Position - wanted).Magnitude < 1e-4).to.equal(true)
				expect(pad.Size).to.equal(CFG.PADS.SIZE)
				expect(pad.Anchored).to.equal(true)
				-- A SHOT MUST PASS STRAIGHT THROUGH IT, `Touched` must never fire (presence here is
				-- arithmetic), and a player must not step up onto a kerb.
				expect(pad.CanQuery).to.equal(false)
				expect(pad.CanTouch).to.equal(false)
				expect(pad.CanCollide).to.equal(false)
				-- IT IS VISIBLE, which the circle's marker was not: this one is the coloured
				-- rectangle Karen asked for.
				-- A TOLERANCE: `Transparency` is a 32-bit property, so 0.45 comes back as
				-- 0.44999998807907104.
				expect(math.abs(pad.Transparency - CFG.PADS.TRANSPARENCY) < 1e-4).to.equal(true)
				-- FOUR DISTINCT COLOURS.
				local key = tostring(pad.Color)
				expect(seen[key]).to.equal(nil)
				seen[key] = true
				-- ...AND ONE BILLBOARD WITH TWO LABELS, saying something from the first frame.
				local board = pad:FindFirstChild("Board")
				expect(board).to.be.ok()
				expect((board :: Instance):IsA("BillboardGui")).to.equal(true)
				local truckLine, countLine = Build.padLabel(index)
				-- AGAINST `Pads.labelFor` ITSELF and not against a second copy of the format, which is
				-- the Reviewer's round-1 note made into a check: the words have ONE formatter now.
				local wantTruck, wantCount = Pads.labelFor(Pads.empty(index), CFG)
				expect(truckLine).to.equal(wantTruck)
				expect(countLine).to.equal(wantCount)
				-- THE TWO ATTRIBUTES ARE THE WHOLE OUTBOUND WIRE, and they are set at build.
				expect(pad:GetAttribute(Data.PAD_STATE_ATTRIBUTE)).to.equal(Data.PAD_STATE.EMPTY)
				expect(pad:GetAttribute(Data.PAD_FIRST_ATTRIBUTE)).to.equal(nil)
			end
			-- PAD 1 IS THE ONE `Build.build` HANDS BACK as its marker, and it is `TruckSpot`.
			expect(Data.padPartName(1)).to.equal(Data.SPOT_NAME)
		end)

		it("sits each pad on the ground that is REALLY there, when a world can measure it", function()
			-- THE CORRECTION THIS TASK MADE AFTER LOOKING AT IT (rule 5). Measured in the live Forest
			-- Test place, 2026-10-14: every pad's top was 149.828 and the terrain under it 150.000 --
			-- the four rectangles were 0.17 studs UNDERGROUND and only their billboards showed.
			-- `Field.fill` asks for a terrain block whose top is `shelfY`, and Roblox terrain is
			-- VOXELISED, so the surface the engine produces is rounded to its own grid: 0.75 studs
			-- higher here. A constant lift cannot fix a rounding this system did not choose.
			--
			-- SO THE PAD IS LAID ON `world.groundAt`, and the claim is that its top clears whatever
			-- that reader says -- not that it clears an arithmetic shelf.
			local hump = 3.25
			local probed: { Vector3 } = {}
			local made = Build.build(
				container,
				anchor,
				CFG,
				fakeTemplates(),
				{
					groundAt = function(x: number, z: number): number
						table.insert(probed, Vector3.new(x, 0, z))
						return anchor.Y + hump
					end,
				} :: any
			)
			-- IT ASKED NINE TIMES PER PAD, OVER THAT PAD'S OWN FOOTPRINT (task 213), and the nine
			-- are its centre, its four corners and the middle of its four edges. It asked ONCE per
			-- pad until task 213 brought the pads south onto Karen's gap and the last of the yard's
			-- east hill came up through pad 4's corner: one ray at a nine-stud rectangle's middle
			-- says nothing about its corners, which is task 196's finding on a third surface.
			--
			-- SINCE TASK 186 THE TRUCKS ASK THE SAME READER -- under every wheel, twice, because the
			-- tilt moves the wheels and the ground under them is a new question afterwards -- so the
			-- probe list is no longer the pads' alone. The pads are the LAST `TRUCK.COUNT * 9` of
			-- it, because `Build.build` parks the trucks before it lays the pads, and that ORDER is
			-- what this case pins.
			local PER_PAD = 9
			local padProbes: { Vector3 } = {}
			for index = #probed - CFG.TRUCK.COUNT * PER_PAD + 1, #probed do
				table.insert(padProbes, probed[index])
			end
			expect(#padProbes).to.equal(CFG.TRUCK.COUNT * PER_PAD)
			for index = 1, CFG.TRUCK.COUNT do
				local wanted = Pads.centreFor(anchor, index, CFG)
				-- THE NINE COVER THE RECTANGLE: every corner of this pad is among them, and every
				-- one of them is ON this pad (never on its neighbour, 8 studs away).
				local cornerProbes = 0
				local centres = 0
				for step = 1, PER_PAD do
					local probe = padProbes[(index - 1) * PER_PAD + step]
					expect(math.abs(probe.X - wanted.X) <= CFG.PADS.SIZE.X / 2 + 1e-6).to.equal(true)
					expect(math.abs(probe.Z - wanted.Z) <= CFG.PADS.SIZE.Z / 2 + 1e-6).to.equal(true)
					local onEdgeX = math.abs(math.abs(probe.X - wanted.X) - CFG.PADS.SIZE.X / 2) < 1e-6
					local onEdgeZ = math.abs(math.abs(probe.Z - wanted.Z) - CFG.PADS.SIZE.Z / 2) < 1e-6
					if onEdgeX and onEdgeZ then
						cornerProbes += 1
					end
					if probe.X == wanted.X and probe.Z == wanted.Z then
						centres += 1
					end
				end
				expect(cornerProbes).to.equal(4)
				expect(centres).to.equal(1)
				local deck = made:FindFirstChild(Data.padPartName(index) :: string, true) :: BasePart
				local top = deck.Position.Y + deck.Size.Y / 2
				-- ON the measured ground, lifted by the one number that stops z-fighting -- and
				-- ABOVE it, which is the whole of the defect this case exists for.
				expect(math.abs(top - (anchor.Y + hump + CFG.PADS.LIFT_STUDS)) < 1e-3).to.equal(true)
				expect(top > anchor.Y + hump).to.equal(true)
				-- ...AND NEVER INSIDE THE SLAB THIS SYSTEM LAID ITSELF, which is the half of the
				-- guarantee the measurement must not throw away (the Reviewer's round-1 note).
				expect(top >= anchor.Y + CFG.ROAD.THICK_STUDS).to.equal(true)
				-- ...AND ITS x AND z HAVE NOT MOVED: the RULE is flat, so a measured Y may never
				-- change where the rectangle is.
				expect(deck.Position.X).to.equal(wanted.X)
				expect(deck.Position.Z).to.equal(wanted.Z)
			end
			-- A GROUND BELOW THE ROAD SLAB IS CLAMPED TO IT, so a dip -- or a reader that measured the
			-- terrain UNDER an opaque slab -- cannot bury the deck the way task 177's ring was buried.
			local sunken = Build.build(
				container,
				anchor,
				CFG,
				fakeTemplates(),
				{
					groundAt = function(): number
						return anchor.Y - 5
					end,
				} :: any
			)
			local clamped = sunken:FindFirstChild(Data.SPOT_NAME, true) :: BasePart
			local clampedTop = clamped.Position.Y + clamped.Size.Y / 2
			expect(math.abs(clampedTop - (anchor.Y + CFG.ROAD.THICK_STUDS + CFG.PADS.LIFT_STUDS)) < 1e-3).to.equal(true)

			-- A READER THAT ANSWERS NOTHING LEAVES THE PURE ARITHMETIC STANDING, which is the branch
			-- every other case in this file builds with.
			local blind = Build.build(
				container,
				anchor,
				CFG,
				fakeTemplates(),
				{
					groundAt = function(): number?
						return nil
					end,
				} :: any
			)
			local fallback = blind:FindFirstChild(Data.SPOT_NAME, true) :: BasePart
			expect((fallback.Position - Pads.centreFor(anchor, 1, CFG)).Magnitude < 1e-3).to.equal(true)
		end)

		it("holds no trace of task 177's circle: no ring, no Spot folder, no sign", function()
			-- A DELETION IS ONLY DONE WHEN NOTHING IS LEFT BEHIND. The circle is archived in
			-- `backups/2026-10-14_task-182_the-marked-circle.txt` (rule 7); this is the check that it
			-- is actually gone from the world rather than drawn under the pads.
			expect(folder:FindFirstChild("Spot", true)).to.equal(nil)
			expect(folder:FindFirstChild("SpotSign", true)).to.equal(nil)
			-- ...AND IT NAMES WHAT IT FOUND, rather than asserting `false` and leaving the next
			-- Builder to guess which instance it was.
			local rings = {}
			for _, descendant in ipairs(folder:GetDescendants()) do
				if string.sub(descendant.Name, 1, 3) == "Seg" then
					table.insert(rings, descendant:GetFullName())
				end
			end
			expect(table.concat(rings, ", ")).to.equal("")
		end)

		it("is found by the FOUR READERS the client has, on a lobby that is really in Workspace", function()
			-- THE ONE CASE THAT CANNOT USE A FOLDER OF ITS OWN. `Lobby.padPart`, `padPositions`,
			-- `padStateOf` and `padAsking` all look for `Workspace.Lobby` by name -- that is what
			-- makes them the CLIENT's readers, and a client has no `container` to be handed. So this
			-- builds the real thing in the real place and destroys it again, which is also the only
			-- way `Data.padAsking` -- the dialog's whole visibility rule -- is provable at all.
			--
			-- IT CREATES NO SCRIPT, so the harness's own "no script outside a Rojo path" check is
			-- untouched, and the folder is gone before the case returns.
			local made = Build.build(Workspace, anchor, CFG, fakeTemplates())
			local ok, err = pcall(function()
				expect(#Data.padPositions()).to.equal(CFG.TRUCK.COUNT)
				for index = 1, CFG.TRUCK.COUNT do
					local deck = Data.padPart(index)
					expect(deck).to.be.ok()
					expect((deck :: BasePart).Name).to.equal(Data.padPartName(index))
					local state, first = Data.padStateOf(index)
					expect(state).to.equal(Data.PAD_STATE.EMPTY)
					expect(first).to.equal(nil)
					-- THE POSITION THE CHEVRON IS POINTED AT IS THE PART'S, not a second computation.
					expect((Data.padPositions()[index] - (deck :: BasePart).Position).Magnitude).to.equal(0)
				end
				-- PAD 1 IS WHAT `Lobby.spotPart` STILL ANSWERS, which is what the Director's
				-- `smoke.sh` pivots a player into and what the chevron falls back to.
				expect(Data.spotPart()).to.equal(Data.padPart(1))
				-- NOBODY IS BEING ASKED ANYTHING ON A LOBBY NOBODY IS STANDING IN.
				expect(Data.padAsking(4242)).to.equal(nil)
				-- ...AND WHEN THE SERVER SAYS SO, EXACTLY ONE PAD ASKS EXACTLY ONE MAN. The two lines
				-- come from `Pads.labelFor`, which is the one formatter of what a board says.
				local asking = Pads.empty(3)
				asking.state = Data.PAD_STATE.SIZING
				table.insert(asking.members, 4242)
				expect(Build.setPad(3, Data.PAD_STATE.SIZING, 4242, Pads.labelFor(asking, CFG))).to.equal(true)
				expect(Data.padAsking(4242)).to.equal(3)
				expect(Data.padAsking(4243)).to.equal(nil)
				-- A PAD THAT HAS MOVED ON ASKS NOBODY, even though it still remembers who picked --
				-- which is what stops the dialog re-opening after the party is sized.
				local sized = Pads.empty(3)
				sized.state = Data.PAD_STATE.FILLING
				sized.size = 4
				table.insert(sized.members, 4242)
				expect(Build.setPad(3, Data.PAD_STATE.FILLING, 4242, Pads.labelFor(sized, CFG))).to.equal(true)
				expect(select(2, Data.padStateOf(3))).to.equal(4242)
				expect(Data.padAsking(4242)).to.equal(nil)
			end)
			made:Destroy()
			-- THE MEMOISED READERS DROP A DESTROYED PART rather than answering a stale position,
			-- which is `MapUi.pointsFor`'s rule and the reason every one of them re-checks
			-- `IsDescendantOf(game)`.
			expect(Data.padPart(1)).to.equal(nil)
			expect(#Data.padPositions()).to.equal(0)
			expect(Data.padAsking(4242)).to.equal(nil)
			if not ok then
				error(err, 0)
			end
		end)

		it("writes a pad's words and attributes only when they CHANGE", function()
			-- THE EDGE CLAIM. `Build.setPad` is called every scan by the owner -- the count changes on
			-- a join and a leave, which are not verdicts -- so it has to be free when nothing moved,
			-- or a standing-empty lobby would replicate four attribute writes ten times a second.
			-- THE WORDS COME IN READY, from the one formatter (`Pads.labelFor`); this module WRITES.
			local function words(state: string, size: number?, on: number)
				local pad = Pads.empty(1)
				pad.state = state
				pad.size = size
				for index = 1, on do
					table.insert(pad.members, index)
				end
				return Pads.labelFor(pad, CFG)
			end
			local before = Build.stats().padWrites
			local idleTruck, idleCount = words(Data.PAD_STATE.EMPTY, nil, 0)
			expect(Build.setPad(1, Data.PAD_STATE.EMPTY, nil, idleTruck, idleCount)).to.equal(false)
			expect(Build.stats().padWrites).to.equal(before)
			local askTruck, askCount = words(Data.PAD_STATE.SIZING, nil, 1)
			expect(Build.setPad(1, Data.PAD_STATE.SIZING, 4242, askTruck, askCount)).to.equal(true)
			expect(Build.stats().padWrites).to.equal(before + 1)
			local deck = Build.padPart(1) :: BasePart
			expect(deck:GetAttribute(Data.PAD_STATE_ATTRIBUTE)).to.equal(Data.PAD_STATE.SIZING)
			expect(deck:GetAttribute(Data.PAD_FIRST_ATTRIBUTE)).to.equal(4242)
			expect(select(2, Build.padLabel(1))).to.equal(string.format(CFG.PADS.BILLBOARD.COUNT_UNSET, 1))
			-- THE SAME VALUES AGAIN WRITE NOTHING.
			expect(Build.setPad(1, Data.PAD_STATE.SIZING, 4242, askTruck, askCount)).to.equal(false)
			expect(Build.stats().padWrites).to.equal(before + 1)
			-- A SIZE TURNS `n / -` INTO KAREN'S OWN `n / size`.
			local fillTruck, fillCount = words(Data.PAD_STATE.FILLING, 4, 2)
			expect(Build.setPad(1, Data.PAD_STATE.FILLING, 4242, fillTruck, fillCount)).to.equal(true)
			expect(select(2, Build.padLabel(1))).to.equal("2 / 4")
			-- A PAD THAT DOES NOT EXIST IS REFUSED RATHER THAN CREATED.
			expect(Build.setPad(CFG.TRUCK.COUNT + 5, Data.PAD_STATE.EMPTY, nil, idleTruck, idleCount)).to.equal(false)
		end)

		it("builds a neutral lodge spawn that writes no team and grants no force field", function()
			local spawn = folder:FindFirstChild(Data.SPAWN_NAME, true)
			expect(spawn).to.be.ok()
			expect((spawn :: any):IsA("SpawnLocation")).to.equal(true)
			expect((spawn :: any).Neutral).to.equal(true)
			expect((spawn :: any).Enabled).to.equal(true)
			-- THE ENGINE MUST NEVER WRITE A TEAM: `Match.Body.setTeam` is the one writer of
			-- `Player.Team`, and a pad that changed it would be a second one.
			expect((spawn :: any).AllowTeamChangeOnTouch).to.equal(false)
			-- A `SpawnLocation` grants a 10-second ForceField by default; Karen did not ask for a
			-- bubble round every player at the lodge.
			expect((spawn :: any).Duration).to.equal(0)
		end)

		it("leaves the doorway a GAP: nothing stands in it", function()
			-- Karen asked for a *"door you walk through"*, so the door is the absence of parts. The
			-- leaf, the lintel and the two jambs are all BESIDE or ABOVE the hole, never in it.
			--
			-- THE VOLUME, SAMPLED, AND NOT THE CENTRES. Round 2's note: a centre test passes any part
			-- whose BOX reaches into the opening while its middle sits outside it -- which is most of
			-- the ways a doorway gets blocked, a lintel that hangs too low being the obvious one.
			local room = Build.roomFor(anchor, CFG)
			local origin = anchor + CFG.LODGE.OFFSET
			local frontZ = origin.Z - CFG.LODGE.SIZE.Z / 2
			for stepX = -2, 2 do
				for stepY = 0, 8 do
					for stepZ = -1, 1 do
						-- THE SNAPPED HEIGHT, not the config's wish (round 3's note): the wall is cut
						-- by whole courses, so the opening a player walks through is
						-- `floor(HEIGHT / d) * d` tall and that is the volume to sample.
						local tall = math.floor(CFG.LODGE.DOOR.HEIGHT / CFG.LODGE.LOG_DIAMETER + 0.5)
							* CFG.LODGE.LOG_DIAMETER
						local at = Vector3.new(
							origin.X + stepX * (CFG.LODGE.DOOR.WIDTH / 2 - 0.4) / 2,
							room.centre.Y + 0.3 + stepY * (tall - 0.6) / 8,
							frontZ + stepZ * CFG.LODGE.LOG_DIAMETER / 2
						)
						for _, descendant in ipairs(folder:GetDescendants()) do
							if descendant:IsA("BasePart") and descendant.CanCollide then
								local piece = descendant :: BasePart
								local near = piece.CFrame:PointToObjectSpace(at)
								if
									math.abs(near.X) < piece.Size.X / 2
									and math.abs(near.Y) < piece.Size.Y / 2
									and math.abs(near.Z) < piece.Size.Z / 2
								then
									error(string.format("%s stands in the doorway", piece.Name), 0)
								end
							end
						end
					end
				end
			end
		end)

		it("really CUTS the door and every window out of the log wall, away from the origin too", function()
			-- THE CASE THAT FAILS ON THE BUG THIS LODGE SHIPPED WITH FOR ONE PHOTOGRAPH. An opening
			-- is written in the config as studs from the lodge's own middle; a wall run is built in
			-- WORLD coordinates. Comparing the two cut nothing, and every course was built whole --
			-- a hunting house with no door and no windows at all.
			--
			-- AND IT IS BUILT AT x = 2850, NOT AT THE ORIGIN. The rest of this file anchors at
			-- (0, 100, 0), where the two frames of reference are the same number and the bug cannot
			-- be seen. Karen's lobby is at x 2850, z -2950.
			local far = Vector3.new(2850, 100, -2950)
			local other = Instance.new("Folder")
			other.Name = "LobbyFarSpecWorld"
			other.Parent = Workspace
			-- EVEN THE BUILD ITSELF (round 3's note): a throw inside `Build.build` would leave this
			-- folder, and its enabled `SpawnLocation`, in `Workspace` for the rest of the run.
			local ok, built = pcall(Build.build, other, far, CFG, nil)
			if not ok then
				other:Destroy()
				error(tostring(built), 0)
			end
			local origin = far + CFG.LODGE.OFFSET
			local room = Build.roomFor(far, CFG)
			local d = CFG.LODGE.LOG_DIAMETER
			local holes = {
				{
					at = Vector3.new(
						origin.X,
						room.centre.Y + CFG.LODGE.DOOR.HEIGHT / 2,
						origin.Z - room.halfZ - d / 2
					),
					fills = "DoorLintel",
					door = true,
				},
			}
			for index, row in ipairs(CFG.LODGE.WINDOWS) do
				local y = room.centre.Y + CFG.LODGE.WINDOW.SILL_STUDS + CFG.LODGE.WINDOW.HEIGHT / 2
				local at
				if row.wall == "south" then
					at = Vector3.new(origin.X + row.along, y, origin.Z - room.halfZ - d / 2)
				elseif row.wall == "north" then
					at = Vector3.new(origin.X + row.along, y, origin.Z + room.halfZ + d / 2)
				elseif row.wall == "west" then
					at = Vector3.new(origin.X - room.halfX - d / 2, y, origin.Z + row.along)
				else
					at = Vector3.new(origin.X + room.halfX + d / 2, y, origin.Z + row.along)
				end
				table.insert(holes, { at = at, fills = string.format("WindowGlass%d", index), door = false })
			end
			local filled = nil
			local problem = nil
			for _, hole in ipairs(holes) do
				for _, descendant in ipairs(built:GetDescendants()) do
					if descendant:IsA("BasePart") and string.match(descendant.Name, "^Wall%u") then
						local piece = descendant :: BasePart
						-- A LOG IS A CYLINDER whose length is its X, so its box in its own frame is
						-- the test: a wall log containing the middle of an opening is an opening
						-- that was never cut.
						local near = piece.CFrame:PointToObjectSpace(hole.at)
						local inside = math.abs(near.X) < piece.Size.X / 2
							and math.abs(near.Y) < piece.Size.Y / 2
							and math.abs(near.Z) < piece.Size.Z / 2
						if inside and filled == nil then
							filled = piece.Name
						end
					end
				end
			end
			-- ...AND THE HOLE IS EXACTLY AS TALL AS THE THING THAT FILLS IT. ROUND 1'S BLOCKING
			-- FINDING, as the case that fails without the fix: a log is a whole cylinder, so a course
			-- that overlaps an opening at all is DROPPED and the hole in the wall is always a whole
			-- number of courses -- 1.8 to 9.0 studs, while a frame built to `SILL_STUDS` 3.4 and
			-- `HEIGHT` 4.4 covered 3.4 to 7.8. Two open slots per window, eight in the house, at knee
			-- height and over the head.
			--
			-- SAMPLED RATHER THAN COMPUTED: walk a line up the wall plane at the opening's own
			-- `along` and ask what is open, which is what an eye inside the room does.
			local step = 0.15
			for _, hole in ipairs(holes) do
				local lowest, highest = nil, nil
				local wallTop = room.centre.Y + room.height
				local y = room.centre.Y + 0.05
				while y < wallTop do
					local at = Vector3.new(hole.at.X, y, hole.at.Z)
					local blocked = false
					for _, descendant in ipairs(built:GetDescendants()) do
						if descendant:IsA("BasePart") and string.match(descendant.Name, "^Wall%u") then
							local piece = descendant :: BasePart
							local near = piece.CFrame:PointToObjectSpace(at)
							if
								math.abs(near.X) < piece.Size.X / 2
								and math.abs(near.Y) < piece.Size.Y / 2
								and math.abs(near.Z) < piece.Size.Z / 2
							then
								blocked = true
								break
							end
						end
					end
					if not blocked then
						lowest = lowest or y
						highest = y
					end
					y += step
				end
				-- NOT ONE THROW BEFORE THE `Destroy` BELOW, AND `expect` THROWS. Round 2, finding 2:
				-- `expect(lowest).to.be.ok()` right here is the "the wall was never cut at all"
				-- failure this case exists to catch, so the first time it did its job it leaked a
				-- live lobby spawn into `Workspace` and poisoned the rest of the run -- the very
				-- defect the round before it had claimed to fix. Every failure is a STRING now, and
				-- nothing is asserted until the folder is gone.
				local fills = built:FindFirstChild(hole.fills, true)
				if lowest == nil then
					problem = problem or string.format("%s: the wall was never cut at all", hole.fills)
				elseif fills == nil or not fills:IsA("BasePart") then
					problem = problem or string.format("%s: nothing was built to fill the hole", hole.fills)
				else
					-- WHAT FILLS IT: the pane for a window, and for the door the floor below and the
					-- lintel above -- both measured off the parts that were really built.
					local board = fills :: BasePart
					local wantLow = if hole.door then room.centre.Y else board.Position.Y - board.Size.Y / 2
					local wantHigh = if hole.door
						then board.Position.Y - board.Size.Y / 2
						else board.Position.Y + board.Size.Y / 2
					if
						math.abs((lowest :: number) - wantLow) > step * 2
						or math.abs((highest :: number) - wantHigh) > step * 2
					then
						problem = problem
							or string.format(
								"the wall is open from %.2f to %.2f but %s covers %.2f to %.2f",
								lowest :: number,
								highest :: number,
								hole.fills,
								wantLow,
								wantHigh
							)
					end
				end
			end
			-- ...AND THE FRAME IS REALLY THERE, so "cut" cannot be satisfied by building no wall.
			local sill = built:FindFirstChild("WindowSill1", true) ~= nil
			local shutter = built:FindFirstChild("Shutter1W", true) ~= nil
			local glass = built:FindFirstChild("WindowGlass1", true) ~= nil
			-- DESTROYED BEFORE ANYTHING IS ASSERTED, AND THAT IS NOT TIDINESS. A lobby carries an
			-- ENABLED `SpawnLocation`; an `error` raised inside the loop above skipped this line
			-- once, the folder stayed in `Workspace` for the rest of the run, and three drive cases
			-- in `zz_drive_boundary` respawned their player three thousand studs from the drive. One
			-- spec bug, four failures.
			other:Destroy()
			if filled ~= nil then
				error(string.format("%s fills an opening that should be a hole", filled), 0)
			end
			if problem ~= nil then
				error(problem, 0)
			end
			expect(sill).to.equal(true)
			expect(shutter).to.equal(true)
			expect(glass).to.equal(true)
		end)

		it("is WALKABLE from the doorway to the counter, and the room is big enough to be one", function()
			-- THE TASK OWN NUMBER: *"interior at least 14x10 studs walkable"*. This is both halves of
			-- it -- the rectangle, and the line a player actually walks along it.
			local room = Build.roomFor(anchor, CFG)
			expect(room.halfX * 2 >= 14).to.equal(true)
			expect(room.halfZ * 2 >= 10).to.equal(true)
			-- A CHARACTER IS ABOUT 5 STUDS TALL AND 2 WIDE. Walk from a stud inside the doorway to
			-- the front of the counter, a step at a time, and let nothing solid stand in the
			-- corridor: the fireplace is on the far side of the room and the table is clamped to its
			-- own offset, but a bench that drifted into the line would be found here rather than by
			-- Karen.
			local counter = folder:FindFirstChild(Data.COUNTER_NAME, true) :: BasePart
			expect(counter).to.be.ok()
			local from = Vector3.new(room.centre.X, room.centre.Y + 2.6, room.centre.Z - room.halfZ + 1.5)
			local to = Vector3.new(counter.Position.X, room.centre.Y + 2.6, counter.Position.Z - counter.Size.Z / 2 - 2)
			local steps = 24
			for step = 0, steps do
				local at = from:Lerp(to, step / steps)
				for _, descendant in ipairs(folder:GetDescendants()) do
					if descendant:IsA("BasePart") and descendant.CanCollide then
						local piece = descendant :: BasePart
						local near = piece.CFrame:PointToObjectSpace(at)
						-- HALF A BODY WIDTH of clearance either side, and the body own height: a
						-- part whose box reaches into that box is a part a player walks into.
						local hitX = math.abs(near.X) < piece.Size.X / 2 + 1
						local hitZ = math.abs(near.Z) < piece.Size.Z / 2 + 1
						local hitY = math.abs(near.Y) < piece.Size.Y / 2 + 2.4
						if hitX and hitY and hitZ then
							error(string.format("%s blocks the walk from the door to the counter", piece.Name), 0)
						end
					end
				end
			end
		end)

		-- TASK 196 REMOVED EVERY DRAWN ANTLER, inside and out. Karen, 2026-10-16: *"remove those fake
		-- antlers we will need real deer head with antlers and boar head"*. What this case asserted --
		-- that the two outside mounts cleared the roof -- is now asserted the only way a removal can
		-- be: nothing is there, under any name, anywhere in the build.
		it("has no drawn antler left on it, inside or out", function()
			expect(folder:FindFirstChild("Antlers", true)).to.equal(nil)
			local suspects = 0
			for _, descendant in ipairs(folder:GetDescendants()) do
				local name = descendant.Name
				if
					string.find(name, "Stag", 1, true)
					or string.find(name, "roe", 1, true)
					or string.find(name, "Antler", 1, true)
					or string.find(name, "Tusk", 1, true)
				then
					suspects += 1
				end
			end
			expect(suspects).to.equal(0)
			-- ...AND THE CATALOGUE OF SIZES WENT WITH THEM: a table nobody reads is a trophy wall
			-- that can come back by accident.
			expect((CFG.TROPHIES :: any).ROE).to.equal(nil)
			expect((CFG.TROPHIES :: any).STAG).to.equal(nil)
			expect((CFG.TROPHIES :: any).GABLE).to.equal(nil)
			expect((CFG.TROPHIES :: any).DOOR).to.equal(nil)
		end)

		it("has a warm inside: a real fire, the lanterns, and the shop counter task 178 fills", function()
			local inside = folder:FindFirstChild("Inside", true)
			expect(inside).to.be.ok()
			-- COUNTED UNDER THE LODGE AND NOT UNDER THE WHOLE LOBBY (task 197). It used to walk
			-- `folder`, which was the same thing until the trucks gained tail lights: eight more
			-- `PointLight`s in the yard made this read 14 against 6. The case is about the lodge's
			-- warm inside, so the lodge is what it counts -- and the trucks' own lights are asserted
			-- by `lobby_live.spec`, where they can be turned on and off.
			local lodge = folder:FindFirstChild("Lodge", true)
			expect(lodge).to.be.ok()
			local lights = 0
			for _, descendant in ipairs((lodge :: Instance):GetDescendants()) do
				if descendant:IsA("PointLight") then
					lights += 1
				end
			end
			-- THE FIRE, THREE LANTERNS INSIDE AND TWO ON THE PORCH, and every one of them is a
			-- `PointLight` written ONCE: nothing in this lodge is animated by a script, so there is
			-- no second writer of anything. The count is read off the config, so a fourth lantern is
			-- a row and not a failing test.
			-- THE TWO TROPHY SCONCES WENT WITH THE NORTH WALL (task 196 part 3d): they were lit for
			-- four heads, and the one mount left is over the fire. The count is back to the fire,
			-- the ceiling lanterns and the two on the porch -- and `TROPHIES.LIGHT` is gone, so a
			-- term reading it here would not even compile.
			expect(lights).to.equal(1 + #CFG.LODGE.LANTERN.ALONG + 2)
			-- KAREN ASKED FOR A FIREPLACE WITH A FIRE IN IT: the `Fire`, the embers and the light
			-- all hang on the one part, which is what makes "the fire is present" checkable.
			local fire = folder:FindFirstChild("Fire", true)
			expect(fire).to.be.ok()
			expect((fire :: Instance):FindFirstChildOfClass("Fire")).to.be.ok()
			expect((fire :: Instance):FindFirstChildOfClass("ParticleEmitter")).to.be.ok()
			expect((fire :: Instance):FindFirstChildOfClass("PointLight")).to.be.ok()
			expect(folder:FindFirstChild("FireplaceMantel", true)).to.be.ok()
			expect(folder:FindFirstChild("FireplaceHearth", true)).to.be.ok()
			expect(folder:FindFirstChild("Counter", true)).to.be.ok()
			local shopSign = folder:FindFirstChild("ShopSign", true)
			expect(shopSign).to.be.ok()
			local label = (shopSign :: Instance):FindFirstChild("Text", true)
			expect(label).to.be.ok()
			expect((label :: TextLabel).Text).to.equal(CFG.LODGE.SIGN_TEXT)
		end)

		-- TASK 177'S "STAND HERE TO HUNT" SIGN POST IS GONE WITH THE CIRCLE (task 182). What a pad
		-- is for is written on the pad's own billboard -- `STEP ON TO HUNT` is not a sign in the
		-- yard, it is the count line before anybody is on it -- and the case above asserts that no
		-- sign survives.

		it("holds no Script, LocalScript or ModuleScript anywhere in the tree", function()
			-- CLAUDE.md: nothing script-like is ever created outside a Rojo-owned path, and the
			-- harness fails if one exists. A world builder is the one place that could break it.
			for _, descendant in ipairs(folder:GetDescendants()) do
				expect(descendant:IsA("LuaSourceContainer")).to.equal(false)
			end
		end)

		it("rebuilds in place rather than leaving two lodges standing", function()
			local again = Build.build(container, anchor, CFG)
			expect(again).to.be.ok()
			local found = 0
			for _, child in ipairs(container:GetChildren()) do
				if child.Name == Data.FOLDER_NAME then
					found += 1
				end
			end
			expect(found).to.equal(1)
		end)
	end)

	-- ------------------------------------------------ the free models, and the fallback (task 180)
	--
	-- KAREN, 2026-10-14 ~09:30: *"we need car truck model or hunting bus also use free model"*, and
	-- ~21:30, on the free cabins: *"all of then garbadge ... you build then one proper europen
	-- standart"*.
	--
	-- SO SINCE TASK 187 THE FREE MODELS ARE THE TRUCK AND THE TREES, AND NOTHING ELSE. The lodge and
	-- every trophy on its walls are ours, which is what the first two cases below are for: the house
	-- is the SAME house whether or not the template folder exists at all.
	--
	-- THE CLAIM THAT MATTERS MOST HERE IS STILL THE FALLBACK. The models live in
	-- `Workspace.LobbyAssets`, which is Studio content in ONE place; the lobby still has to build in
	-- the other one, in a place where somebody renamed the folder, and in this spec.
	describe("the free models, and what happens without them", function()
		local anchor = Vector3.new(0, 100, 0)
		local container

		beforeEach(function()
			container = Instance.new("Folder")
			container.Name = "LobbyModelSpecWorld"
			container.Parent = Workspace
		end)

		afterEach(function()
			container:Destroy()
		end)

		it("builds OUR lodge and the four trucks out of the templates", function()
			local templates = fakeTemplates()
			local folder, _marker, _spawn, count = Build.build(container, anchor, CFG, templates)
			local stats = Build.stats()
			-- NO CLONED HOUSE, EVER AGAIN (task 187). `House` was the free cabin Karen called
			-- *"garbadge"*. The load-bearing half of this is the CONFIG -- there is no lodge template
			-- name left to look for, so no folder anybody parks in `Workspace` can bring one back --
			-- and the wall below is what says our own was built instead. (Review round 1, note: the
			-- `House` line alone cannot fail, because `fakeTemplates` no longer makes one.)
			expect((CFG :: any).LODGE.MODEL).to.never.be.ok()
			expect((Data.TEMPLATE :: any).LODGE).to.never.be.ok()
			expect((Data.TEMPLATE :: any).DEER).to.never.be.ok()
			expect(folder:FindFirstChild("House", true)).to.never.be.ok()
			expect(folder:FindFirstChild("WallN1_1", true)).to.be.ok() -- the back wall lowest log
			for index = 1, CFG.TRUCK.COUNT do
				expect(folder:FindFirstChild(string.format("Truck%d", index), true)).to.be.ok()
			end
			expect(folder:FindFirstChild("TreeLine")).to.be.ok()
			-- FOUR TRUCKS AND MOST OF THE TREE LINE, and nothing else is a clone any more.
			-- It is a BOUND and not an equality on purpose: the arc crosses the road corridor and a
			-- tree that would stand in the road is skipped, so `TREELINE.COUNT` is how many are
			-- ATTEMPTED and never how many are placed.
			local trees = stats.models - CFG.TRUCK.COUNT
			expect(trees > 0).to.equal(true)
			-- THE RING **AND** THE GROVE (part 3c): `lodgeTrees` plants `LODGE_TREES` as well since
			-- part 3b, and `stats.models` counts every clone, so a bound of `COUNT` alone was a test
			-- that could only fail.
			expect(trees <= CFG.TREELINE.COUNT + #CFG.LODGE_TREES).to.equal(true)
			-- 10 AND NOT 6 SINCE TASK 196 PART 3B: the ring has a FOURTH exclusion now -- the corridor
			-- in front of the house, which Karen was looking at when she asked what was wrong with
			-- the trees next to it -- and the count is a BOUND rather than an equality for exactly
			-- this reason.
			expect(trees >= CFG.TREELINE.COUNT - 10).to.equal(true)
			-- A TREE IS THE SIZE OF ITS TEMPLATE TIMES ITS SCALE, and nothing else (part 3c). The
			-- fixture's birch DISPLAYS 30 studs tall at `GetScale() = 0.25`, so at `SCALE` 0.85 ..
			-- 1.35 and `ALDER.SCALE` 0.66 .. 0.82 every planted tree is between 19.8 and 40.5 studs.
			-- ON THE OLD `ScaleTo(scale)` THE BIRCHES CAME OUT AT 102 .. 162 AND THIS FAILS.
			local tallest = 0
			for _, one in ipairs((folder:FindFirstChild("TreeLine") :: Instance):GetChildren()) do
				local _, extent = (one :: Model):GetBoundingBox()
				tallest = math.max(tallest, extent.Y)
			end
			expect(tallest > 0).to.equal(true)
			expect(tallest <= 30 * CFG.TREELINE.SCALE[2] + 0.01).to.equal(true)
			-- THE FALLBACKS ARE THE LODGE'S OWN ASSETS AND NOTHING ELSE (task 196). Every free-model
			-- template this build asks the FOLDER for is found; what is missing is what the
			-- COMPOSITION ROOT hands over -- the boar for the trophy and the guns for the rack --
			-- and a spec hands over none, so each of those counts one fallback. A number and not a
			-- zero, so a truck or a tree that stopped being found still fails this.
			expect(stats.fallbacks).to.equal(#CFG.TROPHIES.MOUNTS + CFG.LODGE.RACK.GUNS)
			expect(count <= CFG.MAX_PARTS).to.equal(true)
			templates:Destroy()
		end)

		-- NOTHING THROUGH THE ROOF (task 196 part 3c). The Director read two birch trunks crossing the
		-- roof slope and one hanging through the porch off `D-house-and-trees.png`, and the reason
		-- the part-3b check missed them is that it tested the PLANTING POINT: these models lean, so
		-- a pivot twenty studs clear of the house is no evidence at all about the trunk.
		it("keeps every tree PART, not every tree pivot, out of the lodge's own volume", function()
			local templates = fakeTemplates()
			local folder = Build.build(container, anchor, CFG, templates)
			local keepAt, keepHalf = Build.lodgeKeepOut(CFG)
			keepAt += anchor
			local inside = 0
			for _, group in ipairs({ "TreeLine", "LodgeTrees" }) do
				local at = folder:FindFirstChild(group)
				expect(at).to.be.ok()
				for _, tree in ipairs((at :: Instance):GetChildren()) do
					-- THE TREE'S REAL WORLD BOX AND NOT `Model:GetBoundingBox()` (part 3c): that one
					-- is ORIENTED, and every tree here is turned by a random yaw, which is how the
					-- first version of this check passed with seven tree parts in the house.
					local boxAt, boxHalf = Build.worldBoxOf(tree)
					if Build.boxesOverlap(boxAt, boxHalf, keepAt, keepHalf, 3) then
						inside += 1
					end
				end
			end
			expect(inside).to.equal(0)
			templates:Destroy()
		end)

		-- NO TREE STANDS ON ITS ROOTS IN THE AIR (task 196 part 3d). KAREN, 2026-10-16, with a
		-- photograph: *"look at the trees wtf"* -- birches on their splayed root flares with one to
		-- three studs of daylight under them, beside a road cut.
		--
		-- THE GROUND UNDER A TREE IS NOT ONE NUMBER, and that is the whole bug. `plantY` asked for
		-- the ground at the PLANTING POINT and the model's lowest point was put there; a birch's
		-- root flare is eight or nine studs across, so on a bank the ground under the OUTER tips is
		-- lower and the tree stands on the high side. The part-3c check made the identical mistake
		-- in the identical place -- it rayed once, at the box's centre -- which is why it reported
		-- zero while Karen was looking at this.
		it("seats every tree on the LOWEST ground anywhere under it, not the ground at its foot", function()
			local templates = fakeTemplates()
			-- A GROUND THAT FALLS AWAY, which is what a road cut is: flat at 0 until x = 40, then
			-- down one stud for every two. A single sample at a tree's foot cannot see it.
			local function slope(x: number, _z: number): number
				return anchor.Y + (if x > 40 then -(x - 40) / 2 else 0)
			end
			local folder = Build.build(container, anchor, CFG, templates, { terrainAt = slope } :: any)
			local worst, worstName = -math.huge, "-"
			for _, group in ipairs({ "TreeLine", "LodgeTrees" }) do
				local at = folder:FindFirstChild(group)
				expect(at).to.be.ok()
				for _, tree in ipairs((at :: Instance):GetChildren()) do
					local boxAt, boxHalf = Build.worldBoxOf(tree)
					local low = math.huge
					for _, point in ipairs(Build.footprintSamples(boxAt - boxHalf, boxAt + boxHalf, 4)) do
						low = math.min(low, slope(point.X, point.Y))
					end
					local gap = (boxAt.Y - boxHalf.Y) - low
					if gap > worst then
						worst, worstName = gap, tree.Name
					end
				end
			end
			-- AT OR BELOW THE LOWEST GROUND UNDER IT, everywhere. Roots on the HIGH side go into the
			-- bank, which is what a root does and which nobody can see.
			if worst > 0.2 then
				error(string.format("%s stands %.2f studs above the ground under it", worstName, worst), 0)
			end
			templates:Destroy()
		end)

		-- TREE-TO-GROUND CONTACT (task 196 part 3e), written in the shape of the trucks' own
		-- wheels-on-the-ground case, because it is the same claim: the thing a player SEES touching
		-- the ground is touching it.
		--
		-- WHAT IS MEASURED IS THE TRUNK/FLARE JUNCTION, not the model's lowest point. A birch's
		-- root flare is a set of arched claws, so seating the claw TIPS on the ground leaves
		-- daylight under every arch -- which is what Karen photographed twice, and what part 3d's
		-- check could not see because it measured the same lowest point the planter had seated.
		-- THIS CASE FAILS AT THE PRE-FIX COMMIT: there the junction sits a whole claw-height above
		-- the ground (0.075 of the model's height, 3.5 to 7.5 studs on these trees).
		it("buries each tree's root claws: the trunk/flare junction is AT or UNDER the ground", function()
			local templates = fakeTemplates()
			local function slope(x: number, _z: number): number
				return anchor.Y + (if x > 40 then -(x - 40) / 2 else 0)
			end
			local folder = Build.build(container, anchor, CFG, templates, { terrainAt = slope } :: any)
			local byModel: { [string]: number } = {}
			for _, row in ipairs(CFG.TREELINE.SPECIES) do
				byModel[row.KIND] = row.CLAW_FRACTION or 0
			end
			-- EVERY SPECIES CARRIES THE NUMBER, because a species added without one would be
			-- planted on its claw tips and nothing would say so.
			for _, row in ipairs(CFG.TREELINE.SPECIES) do
				expect(type(row.CLAW_FRACTION)).to.equal("number")
				expect(row.CLAW_FRACTION > 0).to.equal(true)
			end
			local worst, worstName = -math.huge, "-"
			for _, group in ipairs({ "TreeLine", "LodgeTrees" }) do
				local at = folder:FindFirstChild(group)
				expect(at).to.be.ok()
				for _, tree in ipairs((at :: Instance):GetChildren()) do
					local boxAt, boxHalf = Build.worldBoxOf(tree)
					local min, max = boxAt - boxHalf, boxAt + boxHalf
					-- THE FIXTURE'S TREES ARE ALL ONE SPECIES-WIDTH APART, so the claw fraction is
					-- taken as the SMALLEST any species uses: a tree buried by more than its own
					-- claw is still buried.
					local claw = math.huge
					for _, value in pairs(byModel) do
						claw = math.min(claw, value)
					end
					local junction = min.Y + (max.Y - min.Y) * claw
					local low = math.huge
					for _, point in ipairs(Build.footprintSamples(min, max, 4)) do
						low = math.min(low, slope(point.X, point.Y))
					end
					local gap = junction - low
					if gap > worst then
						worst, worstName = gap, tree.Name
					end
				end
			end
			-- AT OR UNDER, never above: the claws are in the ground.
			if worst > 0 then
				error(string.format("%s shows %.2f studs of claw above the ground under it", worstName, worst), 0)
			end
			-- ...AND IT IS NOT ZERO ON EVERY TREE EITHER (standing rule E, lesson L-028): a metric
			-- that reads exactly 0.00 everywhere is a metric nobody has checked. These are sunk by
			-- their own claw height plus `SINK_STUDS`, so the worst is a real negative number.
			expect(worst < -CFG.TREELINE.SINK_STUDS / 2).to.equal(true)
			templates:Destroy()
		end)

		-- THE WALKABLE SURFACE (task 196 part 3f). This lobby lays its road, its verges and its yard
		-- as PARTS on top of the terrain, half a stud proud of it, and a tree seated by the terrain
		-- alone would be planted UNDER one and come up through it.
		it("plants a tree on the road slab's top, not on the terrain hidden under it", function()
			local slab = Instance.new("Part")
			slab.Size = Vector3.new(20, 0.5, 160)
			slab.CFrame = CFrame.new(10, 100.25, 0)
			local over = Build.surfaceOver({ slab }, 10, 0)
			expect(over).to.be.ok()
			expect(math.abs((over :: number) - 100.5) < 1e-3).to.equal(true)
			-- ...AND NOTHING OUTSIDE ITS FOOTPRINT, which is what keeps a slab from lifting a tree
			-- standing beside the road.
			expect(Build.surfaceOver({ slab }, 10 + 10.1, 0)).to.equal(nil)
			expect(Build.surfaceOver({ slab }, 10, 81)).to.equal(nil)
			-- THE HIGHEST ONE WINS where two overlap: the verges are laid 0.05 under the lane and a
			-- tree on the join belongs on the lane.
			local upper = Instance.new("Part")
			upper.Size = Vector3.new(4, 1.6, 2)
			upper.CFrame = CFrame.new(10, 101, 0)
			local both = Build.surfaceOver({ slab, upper }, 10, 0)
			expect(math.abs((both :: number) - 101.8) < 1e-3).to.equal(true)
			slab:Destroy()
			upper:Destroy()
		end)

		-- THE SAMPLING PATTERN ITSELF, pure, because the case above can only prove that today's
		-- slope happens to be caught.
		it("samples the whole footprint and its corners, not just the middle", function()
			local min, max = Vector3.new(-4, 0, -6), Vector3.new(4, 0, 6)
			local points = Build.footprintSamples(min, max, 4)
			expect(#points).to.equal(25)
			local tips = 0
			local middle = 0
			for _, point in ipairs(points) do
				local onX = math.abs(math.abs(point.X) - 4) < 1e-4
				local onZ = math.abs(math.abs(point.Y) - 6) < 1e-4
				if onX and onZ then
					tips += 1
				end
				if math.abs(point.X) < 1e-4 and math.abs(point.Y) < 1e-4 then
					middle += 1
				end
			end
			-- ALL FOUR CORNERS, because that is where the root tips are...
			expect(tips).to.equal(4)
			-- ...and the middle, because that is where the trunk is.
			expect(middle).to.equal(1)
			-- A DEGENERATE FOOTPRINT STILL ANSWERS SOMETHING, never an empty list.
			expect(#Build.footprintSamples(Vector3.zero, Vector3.zero, 0)).to.equal(9)
		end)

		-- THE KEEP-OUT BOX ITSELF, pure, because the case above can only ever prove that today's
		-- numbers happen to miss the house.
		it("draws the keep-out box round the eaves, the gables and the porch", function()
			local at, half = Build.lodgeKeepOut(CFG)
			-- A `Vector3` COMPONENT IS A 32-BIT FLOAT and the arithmetic that made it is not, so
			-- 20.2 comes back as 20.200000762939453. Every comparison here is to a tolerance.
			local widest = math.max(CFG.LODGE.ROOF.GABLE_STUDS, CFG.LODGE.CHIMNEY.BASE_DEPTH / 2) + CFG.LODGE.SIZE.X / 2
			expect(math.abs(half.X - widest) < 1e-3).to.equal(true)
			-- THE PORCH SIDE IS LONGER THAN THE BACK, so the box is not centred on the house.
			expect(at.Z < CFG.LODGE.OFFSET.Z).to.equal(true)
			local front = at.Z - half.Z - CFG.LODGE.OFFSET.Z
			expect(front <= -(CFG.LODGE.SIZE.Z / 2 + CFG.LODGE.PORCH.DEPTH)).to.equal(true)
			-- IT REACHES THE RIDGE, so a crown over the roof counts as through it.
			expect(at.Y + half.Y >= CFG.LODGE.RIDGE_STUDS).to.equal(true)
			-- AND THE OVERLAP TEST APPLIES ITS MARGIN IN BOTH DIRECTIONS.
			local one = Vector3.new(1, 1, 1)
			expect(Build.boxesOverlap(Vector3.zero, one, Vector3.new(2.5, 0, 0), one, 0)).to.equal(false)
			expect(Build.boxesOverlap(Vector3.zero, one, Vector3.new(2.5, 0, 0), one, 1)).to.equal(true)
		end)

		-- ONE MOUNT, AND IT IS THE ONE OVER THE FIRE (task 196 part 3d). KAREN, 2026-10-16:
		-- *"remove table and all boar heads only keep one where is on fireplace"*.
		it("hangs ONE trophy, on the fireplace wall, with its point and nothing behind it", function()
			local folder = Build.build(container, anchor, CFG, nil)
			local spec = CFG.TROPHIES
			-- EXACTLY ONE ROW, AND IT IS THE WEST WALL'S -- the chimney breast over the fire.
			expect(#spec.MOUNTS).to.equal(1)
			expect(spec.MOUNTS[1].wall).to.equal("west")
			-- NOTHING IS LEFT ON THE NORTH WALL. A mount folder is `Mount<n>`, so a second one
			-- existing at all is four heads that did not go.
			expect(folder:FindFirstChild("Mount2", true)).to.equal(nil)
			-- ...AND THE TWO THINGS THAT EXISTED ONLY FOR THEM WENT WITH THEM: the boarded back
			-- store that swallowed four rumps, and the two sconces that lit four heads.
			expect(folder:FindFirstChild("TrophyBacking", true)).to.equal(nil)
			expect(folder:FindFirstChild("SconceFlame1", true)).to.equal(nil)
			expect((spec :: any).BACKING).to.equal(nil)
			expect((spec :: any).LIGHT).to.equal(nil)
			-- THE SHIELD KEEPS ITS POINT (part 3c): it was a `WedgePart` laid flat, which read as a
			-- shelf under the plaque -- its thickness along x and its 3.2 studs of width INTO the
			-- room. The one that is left is the one Karen looks at.
			local tip = folder:FindFirstChild(string.format("%s1Point", spec.MOUNTS[1].kind), true)
			expect(tip).to.be.ok()
			local point = tip :: BasePart
			expect(point:IsA("WedgePart")).to.equal(false)
			expect(math.abs(point.Size.Z - spec.SHIELD.BOARD_THICK) < 1e-3).to.equal(true)
			-- THE RED STAG'S PLACE IS A MEASUREMENT NOW AND NOT TWO PARTS (part 3e). On a wall with
			-- no trophies left, two iron pins read as two stray dots -- so the row keeps WHERE he
			-- will hang and builds nothing.
			expect(folder:FindFirstChild("StagPeg1", true)).to.equal(nil)
			expect(spec.STAG_PLACE).to.be.ok()
			expect(#spec.STAG_PLACE.ALONG).to.equal(2)
			expect((spec.STAG_PLACE :: any).PEG_ALONG).to.equal(nil)
		end)

		-- NO TABLE, NO BENCHES, AND NO BENCH LEFT BEHIND (task 196 part 3d). The benches went WITH
		-- the table, because a bench facing nothing in the middle of an empty room reads as a
		-- leftover rather than as furniture.
		it("has no table and no bench left inside the room", function()
			local folder = Build.build(container, anchor, CFG, nil)
			expect((CFG.LODGE :: any).TABLE).to.equal(nil)
			local left = {}
			for _, descendant in ipairs(folder:GetDescendants()) do
				local name = descendant.Name
				-- `PorchBench` IS NOT THE DINING SET and stays: it is on the deck, against the wall,
				-- by the door, and it never had a table.
				if
					descendant:IsA("BasePart")
					and not string.find(name, "Porch", 1, true)
					and (string.match(name, "^Table") or string.match(name, "^Bench"))
				then
					table.insert(left, name)
				end
			end
			if #left > 0 then
				error(string.format("still standing: %s", table.concat(left, ", ")), 0)
			end
		end)

		it("builds the SAME lodge when the template folder is not there at all", function()
			local folder, _marker, _spawn, count = Build.build(container, anchor, CFG, nil)
			local stats = Build.stats()
			-- THE DEV PLACE HAS NEVER HAD THE TEMPLATES, and the harness runs there: the house, its
			-- fire and its antlers must not depend on Studio content that exists in one place.
			expect(folder:FindFirstChild("WallN1_1", true)).to.be.ok()
			expect(folder:FindFirstChild("Floor", true)).to.be.ok()
			expect(folder:FindFirstChild("Plinth", true)).to.be.ok()
			expect(folder:FindFirstChild("ChimneyStack", true)).to.be.ok()
			expect(folder:FindFirstChild("Fire", true)).to.be.ok()
			expect(folder:FindFirstChild("Trophies", true)).to.be.ok()
			for index = 1, CFG.TRUCK.COUNT do
				local made = folder:FindFirstChild(string.format("Truck%d", index), true)
				expect(made).to.be.ok()
				expect((made :: Instance):FindFirstChild("Cab")).to.be.ok() -- the parts truck
			end
			expect(folder:FindFirstChild("TreeLine")).to.never.be.ok()
			expect(stats.models).to.equal(0)
			expect(count <= CFG.MAX_PARTS).to.equal(true)
			expect(count > 50).to.equal(true)
		end)

		it("falls back one piece at a time when only some of the templates are there", function()
			local templates = fakeTemplates()
			local truckTemplate = templates:FindFirstChild(Data.TEMPLATE.TRUCK) :: Instance
			truckTemplate:Destroy()
			local folder = Build.build(container, anchor, CFG, templates)
			expect(folder:FindFirstChild("TreeLine")).to.be.ok() -- the trees are still clones
			local first = folder:FindFirstChild("Truck1", true)
			expect(first).to.be.ok()
			expect((first :: Instance):FindFirstChild("Cab")).to.be.ok() -- ...and parts trucks
			expect(Build.stats().fallbacks >= CFG.TRUCK.COUNT).to.equal(true)
			templates:Destroy()
		end)

		it("strips a script a free model smuggled in, and says how many", function()
			local templates = fakeTemplates(true)
			local folder = Build.build(container, anchor, CFG, templates)
			-- ONE SCRIPT IN THE TEMPLATE, ONE PER CLONE OF IT: the truck is parked in four bays, so
			-- four is the right answer and `1` would mean three of them got through.
			expect(Build.stats().strippedScripts).to.equal(CFG.TRUCK.COUNT)
			for _, descendant in ipairs(folder:GetDescendants()) do
				expect(descendant:IsA("LuaSourceContainer")).to.equal(false)
			end
			-- and the TEMPLATE is untouched: the clone was stripped, never the original
			expect(templates:FindFirstChild("Fire_Effect", true)).to.be.ok()
			templates:Destroy()
		end)

		it("anchors every cloned part, however the free model shipped it", function()
			local templates = fakeTemplates()
			local folder = Build.build(container, anchor, CFG, templates)
			for _, descendant in ipairs(folder:GetDescendants()) do
				if descendant:IsA("BasePart") then
					expect(descendant.Anchored).to.equal(true)
				end
			end
			templates:Destroy()
		end)

		-- **THE ROW STEPS SOUTH SINCE TASK 243 AND THE TRUCKS STAND `BACK_STUDS` EAST OF THEIR BAYS**
		-- (Karen: *"there has to be cars but looking at me ... but not close to house there has to be
		-- distance"*). Same two facts as before, on the other axis: bay 1 is where it says it is, and
		-- every bay after it is exactly one `BAY_GAP_STUDS` from the last.
		it("parks the trucks in a row, a bay apart, starting where 177's one truck stood", function()
			local templates = fakeTemplates()
			local folder = Build.build(container, anchor, CFG, templates)
			local previous = 0
			for index = 1, CFG.TRUCK.COUNT do
				local made = folder:FindFirstChild(string.format("Truck%d", index), true) :: Model
				local at = made:GetPivot().Position
				-- ONE x FOR THE WHOLE ROW, and it is the bay's own x pushed east by `BACK_STUDS`.
				expect(math.abs(at.X - (anchor.X + CFG.TRUCK.OFFSET.X + CFG.TRUCK.BACK_STUDS)) < 0.01).to.equal(true)
				if index == 1 then
					expect(math.abs(at.Z - (anchor.Z + CFG.TRUCK.OFFSET.Z)) < 0.01).to.equal(true)
				else
					expect(math.abs((previous - at.Z) - CFG.TRUCK.BAY_GAP_STUDS) < 0.01).to.equal(true)
				end
				previous = at.Z
			end
			templates:Destroy()
		end)

		-- **ROUND 1'S BLOCKING FINDING 1, AS A CASE THAT FAILS WITHOUT THE FIX.** Task 243 turned the
		-- parts-built fallback truck to face WEST and left `truckRig`'s no-lamp branch asserting
		-- `facing = (0, 0, -1)`, so on that branch -- which is the one EVERY spec and every world
		-- without `Workspace.LobbyAssets.Truck` takes -- the headlamps were built on the truck's
		-- south FLANK, the beams were aimed sideways across the bays, and `lengthHalf` read the
		-- WIDTH half and hung the exhaust and the engine off the wrong end.
		--
		-- IT IS ASSERTED AGAINST THE TRUCK'S OWN BONNET and never against an axis named here, so the
		-- next turn of the yard cannot let the two drift apart again: the direction is measured from
		-- the built `Bumper` out of the built box, and the head lenses have to be on that side of
		-- the centre and the tail lenses on the other.
		it("builds the fallback truck's own lamps at its own bonnet, not at a named axis", function()
			local folder = Build.build(container, anchor, CFG, nil)
			local made = folder:FindFirstChild("Truck1", true)
			expect(made).to.be.ok()
			local centre = Build.worldBoxOf(made :: Instance)
			local bumper = (made :: Instance):FindFirstChild("Bumper") :: BasePart
			expect(bumper).to.be.ok()
			-- THE NOSE, as a direction, out of the geometry `Build.truck` actually built.
			local nose = ((bumper.Position - centre) * Vector3.new(1, 0, 1)).Unit
			local heads, tails = 0, 0
			for _, descendant in ipairs((made :: Instance):GetDescendants()) do
				if descendant:IsA("BasePart") then
					local piece = descendant :: BasePart
					local ahead = nose:Dot((piece.Position - centre) * Vector3.new(1, 0, 1))
					if string.match(piece.Name, "^HeadLamp%d$") then
						heads += 1
						expect(ahead > 0).to.equal(true)
						-- ...AND IT IS OUT AT THE NOSE rather than merely on the right half: past
						-- the bumper's own reach, which is where a lens belongs.
						expect(ahead >= nose:Dot((bumper.Position - centre) * Vector3.new(1, 0, 1)) - 0.01).to.equal(
							true
						)
						-- ...AND THE PART IS TURNED WITH THE TRUCK: a lens is written depth-last, so
						-- its own `-Z` face has to be on the nose and not on world `-z`.
						expect(piece.CFrame.LookVector:Dot(nose) > 0.99).to.equal(true)
					elseif string.match(piece.Name, "^TailLamp%d$") then
						tails += 1
						expect(ahead < 0).to.equal(true)
					end
				end
			end
			-- TWO OF EACH, and `Build.isHeadLamp` still tells them apart by colour alone.
			expect(heads).to.equal(2)
			expect(tails).to.equal(2)
			-- THE TWO HEAD LENSES ARE A PAIR ACROSS THE TRUCK, which is the other half of "at the
			-- nose": one lamp in the middle of the bonnet would pass every test above.
			local across = Vector3.new(-nose.Z, 0, nose.X)
			local lensA = (made :: Instance):FindFirstChild("HeadLamp1") :: BasePart
			local lensB = (made :: Instance):FindFirstChild("HeadLamp2") :: BasePart
			local sideA = across:Dot((lensA.Position - centre) * Vector3.new(1, 0, 1))
			local sideB = across:Dot((lensB.Position - centre) * Vector3.new(1, 0, 1))
			expect(sideA * sideB < 0).to.equal(true)
			expect(math.abs(sideA - sideB) > 1).to.equal(true)
		end)

		it("stands every free model ON the shelf, not in it and not over it", function()
			local templates = fakeTemplates()
			local folder = Build.build(container, anchor, CFG, templates)
			for _, name in ipairs({ "Truck1", "Truck4" }) do
				local made = folder:FindFirstChild(name, true) :: Model
				local box, size = made:GetBoundingBox()
				expect(math.abs((box.Position.Y - size.Y / 2) - anchor.Y) < 0.05).to.equal(true)
			end
			templates:Destroy()
		end)

		-- ------------------------------------------------------------ task 186: the trucks
		--
		-- KAREN, 2026-10-14 ~17:00: *"car tyers are inside earth"*, and ~21:15 *"make cars comoflash
		-- like military like hunting cars"*.
		--
		-- WHAT WAS MEASURED IN THE LIVE PLACE BEFORE ANY OF IT WAS WRITTEN: every tyre of all four
		-- trucks 0.752 studs UNDER the terrain, and the east bay's worst wheel 2.017 under, with a
		-- 1.266-stud spread across that one truck's own four wheels. So there are two claims here
		-- and they are different claims: no wheel may be under its ground (ever, under any reader),
		-- and on ground that really is a plane every wheel must be ON it.
		it("settles every wheel onto the ground a world can measure", function()
			-- A SLOPE, not a step: 0.03 per stud is ~1.7 degrees, which is inside `MAX_TILT_DEGREES`
			-- and well over `MIN_TILT_DEGREES`, so this drives the tilt AND the lift together.
			local function sloped(x: number, _z: number): number
				return anchor.Y + 1 + (x - anchor.X) * 0.03
			end
			-- THE PARTS BUILD, because its trucks have parts named `Wheel` -- the branch the live
			-- free model takes too, through its four `Tire` MeshParts.
			local folder = Build.build(container, anchor, CFG, nil, { groundAt = sloped } :: any)
			expect(Build.stats().trucksSettled).to.equal(CFG.TRUCK.COUNT)
			local wheels = 0
			for index = 1, CFG.TRUCK.COUNT do
				local made = folder:FindFirstChild(string.format("Truck%d", index), true) :: Instance
				for _, piece in ipairs(made:GetDescendants()) do
					if piece:IsA("BasePart") and Build.truckSkinOf(piece.Name, piece.Material) == "tyre" then
						wheels += 1
						local bottom = piece.Position.Y - piece.Size.Y / 2
						local ground = sloped(piece.Position.X, piece.Position.Z)
						-- ON the ground: never under it, and never floating.
						expect(bottom >= ground - 1e-3).to.equal(true)
						expect(bottom - ground <= 0.2).to.equal(true)
					end
				end
			end
			expect(wheels).to.equal(CFG.TRUCK.COUNT * CFG.TRUCK.WHEELS)
			-- ...AND THE WORST OF THEM IS THE NUMBER THE CONSOLE PRINTS.
			expect(Build.stats().truckGroundStuds <= 0.2).to.equal(true)
		end)

		it("never sinks a truck, even where the ground is steeper than it may tilt", function()
			-- THE CLAMP'S OWN CASE. Half a stud per stud is 26 degrees, four times
			-- `MAX_TILT_DEGREES`: the truck CANNOT be stood on that plane, and the one thing it must
			-- still do is not bury a wheel. The lift is the WORST contact's, so the guarantee
			-- survives a tilt that was refused.
			local function cliff(x: number, _z: number): number
				return anchor.Y + (x - anchor.X) * 0.5
			end
			local folder = Build.build(container, anchor, CFG, nil, { groundAt = cliff } :: any)
			for index = 1, CFG.TRUCK.COUNT do
				local made = folder:FindFirstChild(string.format("Truck%d", index), true) :: Instance
				for _, piece in ipairs(made:GetDescendants()) do
					if piece:IsA("BasePart") and Build.truckSkinOf(piece.Name, piece.Material) == "tyre" then
						local bottom = piece.Position.Y - piece.Size.Y / 2
						expect(bottom >= cliff(piece.Position.X, piece.Position.Z) - 1e-3).to.equal(true)
					end
				end
			end
		end)

		it("leaves a truck exactly on the shelf when the world cannot measure the ground", function()
			-- THE FALLBACK IS THE OLD BEHAVIOUR, UNCHANGED, and it is what every other spec in this
			-- file builds with. A reader that throws is the same state as no reader at all: half a
			-- measurement is how a truck ends up tilted onto a wheel whose ground nobody knows.
			local folder = Build.build(
				container,
				anchor,
				CFG,
				nil,
				{
					groundAt = function(): number?
						error("no ground here")
					end,
				} :: any
			)
			expect(Build.stats().trucksSettled).to.equal(0)
			local made = folder:FindFirstChild("Truck1", true) :: Instance
			for _, piece in ipairs(made:GetDescendants()) do
				if piece:IsA("BasePart") and Build.truckSkinOf(piece.Name, piece.Material) == "tyre" then
					expect(math.abs((piece.Position.Y - piece.Size.Y / 2) - anchor.Y) < 1e-3).to.equal(true)
				end
			end
		end)

		it("settles a model whose wheels are not called wheels, on its own footprint", function()
			-- THE SPEC'S STAND-IN TRUCK IS ONE PART CALLED `Body`, and so is any replacement model
			-- whose author named the wheels in another language. Then the contacts are the
			-- FOOTPRINT's four corners, and the claim is the one that always holds: nothing sunk.
			local templates = fakeTemplates()
			local function hump(_x: number, _z: number): number
				return anchor.Y + 2.5
			end
			local folder = Build.build(container, anchor, CFG, templates, { groundAt = hump } :: any)
			expect(Build.stats().trucksSettled).to.equal(CFG.TRUCK.COUNT)
			for index = 1, CFG.TRUCK.COUNT do
				local made = folder:FindFirstChild(string.format("Truck%d", index), true) :: Model
				local box, size = made:GetBoundingBox()
				local lowest = box.Position.Y - size.Y / 2
				expect(lowest >= anchor.Y + 2.5 - 1e-3).to.equal(true)
				expect(lowest - (anchor.Y + 2.5) <= 0.2).to.equal(true)
			end
			templates:Destroy()
		end)

		it("paints every truck in the bay's own camouflage, and leaves the glass alone", function()
			local folder = Build.build(container, anchor, CFG, nil)
			expect(Build.stats().truckPainted > 0).to.equal(true)
			local spec = CFG.TRUCK.CAMO
			for index = 1, CFG.TRUCK.COUNT do
				local made = folder:FindFirstChild(string.format("Truck%d", index), true) :: Instance
				local palette = spec.TONES[(index - 1) % #spec.TONES + 1]
				local tones: { [string]: boolean } = {}
				local panels = 0
				for _, piece in ipairs(made:GetDescendants()) do
					if piece:IsA("BasePart") then
						local skin = Build.truckSkinOf(piece.Name, piece.Material)
						if skin == "body" then
							panels += 1
							local wanted = false
							for _, tone in ipairs(palette) do
								if piece.Color == tone then
									wanted = true
								end
							end
							expect(wanted).to.equal(true)
							expect(piece.Material).to.equal(spec.BODY_MATERIAL)
							tones[tostring(piece.Color)] = true
						elseif skin == "tyre" then
							expect(piece.Color).to.equal(spec.TYRE)
						elseif skin == "glass" then
							-- THE WINDOWS ARE KEPT (the Director's brief), and the parts truck's own
							-- windscreen is what proves it: still glass, still its own colour.
							expect(piece.Material).to.equal(Enum.Material.Glass)
						end
					end
				end
				expect(panels > 0).to.equal(true)
				-- MORE THAN ONE TONE ON ONE TRUCK is the difference between a camouflage scheme and
				-- one flat colour, and it is what the alternating walk through the palette buys.
				local distinct = 0
				for _ in pairs(tones) do
					distinct += 1
				end
				expect(distinct > 1).to.equal(true)
			end
		end)

		it("knows which part of a truck is paint, glass, a lamp or a wheel", function()
			-- PURE, and the ORDER is the claim: `WindowFrame` is a free model's real part name and it
			-- carries both words, so a frame that got painted olive would put an olive bar across a
			-- window. Glass first, then the lamps, then the wheels, and only what is left is paint.
			expect(Build.truckSkinOf("WindowFrame", Enum.Material.Fabric)).to.equal("glass")
			expect(Build.truckSkinOf("Windscreen", Enum.Material.Glass)).to.equal("glass")
			expect(Build.truckSkinOf("Light", Enum.Material.Neon)).to.equal("light")
			expect(Build.truckSkinOf("T", Enum.Material.Neon)).to.equal("light")
			expect(Build.truckSkinOf("Tire", Enum.Material.Fabric)).to.equal("tyre")
			expect(Build.truckSkinOf("Wheel3", Enum.Material.Rubber)).to.equal("tyre")
			expect(Build.truckSkinOf("Rim", Enum.Material.Fabric)).to.equal("rim")
			expect(Build.truckSkinOf("Color", Enum.Material.SmoothPlastic)).to.equal("body")
			expect(Build.truckSkinOf("Bonnet", Enum.Material.Metal)).to.equal("body")
			expect(Build.truckSkinOf("BedSide1", Enum.Material.Metal)).to.equal("body")
			-- ...AND EVERYTHING THIS SYSTEM DID NOT BUILD IS LEFT ALONE: the bumpers, the grille and
			-- the interior ship near-black, which is what a military truck's trim is anyway.
			expect(Build.truckSkinOf("Bumper", Enum.Material.Fabric)).to.equal("keep")
			expect(Build.truckSkinOf("Grill1", Enum.Material.Fabric)).to.equal("keep")
			expect(Build.truckSkinOf("Steering1", Enum.Material.Fabric)).to.equal("keep")
		end)

		it("fits a plane through four ground samples, and refuses to fit a line", function()
			-- PURE. A plane that IS y = 0.2x - 0.1z comes back as exactly that, which is what makes
			-- the tilt a measurement rather than a guess at a direction.
			local points = {}
			for _, x in ipairs({ -5, 5 }) do
				for _, z in ipairs({ -3, 3 }) do
					table.insert(points, { x = x, z = z, y = 10 + 0.2 * x - 0.1 * z })
				end
			end
			local slopeX, slopeZ = Build.groundFit(points)
			expect(math.abs(slopeX - 0.2) < 1e-6).to.equal(true)
			expect(math.abs(slopeZ + 0.1) < 1e-6).to.equal(true)
			-- FLAT GROUND IS FLAT.
			local levelX, levelZ = Build.groundFit({
				{ x = 0, z = 0, y = 7 },
				{ x = 4, z = 0, y = 7 },
				{ x = 0, z = 4, y = 7 },
				{ x = 4, z = 4, y = 7 },
			})
			expect(levelX).to.equal(0)
			expect(levelZ).to.equal(0)
			-- ...AND SAMPLES ALL IN A LINE, OR TOO FEW OF THEM, ANSWER LEVEL rather than dividing by
			-- a determinant at zero: a truck that cannot be fitted stays flat.
			local lineX, lineZ = Build.groundFit({
				{ x = 0, z = 0, y = 1 },
				{ x = 1, z = 0, y = 2 },
				{ x = 2, z = 0, y = 3 },
			})
			expect(lineX).to.equal(0)
			expect(lineZ).to.equal(0)
			local fewX, fewZ = Build.groundFit({ { x = 0, z = 0, y = 1 }, { x = 1, z = 1, y = 9 } })
			expect(fewX).to.equal(0)
			expect(fewZ).to.equal(0)
		end)

		it("clamps the tilt at both ends, so a bad ray cannot tip a truck over", function()
			-- PURE. Level ground is identity, a slope under the floor is identity, a slope over the
			-- ceiling is the ceiling -- and the lean is still the way the ground rises.
			local small = math.rad(0.25)
			local big = math.rad(6)
			expect(Build.tiltFrom(0, 0, small, big)).to.equal(CFrame.identity)
			expect(Build.tiltFrom(0.001, 0, small, big)).to.equal(CFrame.identity)
			local up = Build.tiltFrom(0.5, 0, small, big).UpVector
			-- SIX DEGREES AND NOT TWENTY-SIX: the angle off vertical is the clamp exactly.
			expect(math.abs(math.deg(math.acos(math.clamp(up.Y, -1, 1))) - 6) < 1e-3).to.equal(true)
			-- ...AND IT LEANS THE WAY THE GROUND RISES: a plane climbing in +x tips the up vector
			-- back toward -x.
			expect(up.X < 0).to.equal(true)
			local inside = Build.tiltFrom(0.05, 0, small, big).UpVector
			local leaned = math.deg(math.acos(math.clamp(inside.Y, -1, 1)))
			expect(math.abs(leaned - math.deg(math.atan(0.05))) < 1e-3).to.equal(true)
		end)

		it("keeps the road, the fences and the trees inside the field's own rectangle", function()
			-- THE SAME BOUND `Field.fill` IS HELD TO. The shelf is 220 x 220 and nothing else is
			-- flat: a verge or a fence post laid past its edge would float over the fall the raycast
			-- grid measured, which is the failure this project is named after.
			local templates = fakeTemplates()
			local folder = Build.build(container, anchor, CFG, templates)
			local half = CFG.FIELD.SPAN_STUDS / 2
			for _, group in ipairs({ "Road", "Fences", "TreeLine" }) do
				local made = folder:FindFirstChild(group)
				expect(made).to.be.ok()
				for _, descendant in ipairs((made :: Instance):GetDescendants()) do
					if descendant:IsA("BasePart") then
						local at = descendant.Position
						expect(math.abs(at.X - anchor.X) <= half).to.equal(true)
						expect(math.abs(at.Z - anchor.Z) <= half).to.equal(true)
					end
				end
			end
			templates:Destroy()
		end)

		it("hangs every trophy INSIDE the room, under its ceiling, and off the wall it names", function()
			-- THE BOUND IS THE ROOM AND NOT THE LODGE FOOTPRINT, which is task 180 round 1 finding 3:
			-- a footprint bound is a stud and a half outside the wall and cannot see the bug it was
			-- written for -- an inverted yaw puts a plaque a quarter of a stud past its own wall, in
			-- the open air. `Build.roomFor` is the same rectangle the mount itself used.
			--
			-- EVERY PART OF EVERY MOUNT is checked and not just the shield: the antler beams reach a
			-- stud and a half further out than the plaque and three higher, so they are the half of a
			-- mistake that goes through the wall or the boards first.
			local folder = Build.build(container, anchor, CFG, fakeTemplates())
			local room = Build.roomFor(anchor, CFG)
			local heads = folder:FindFirstChild("Trophies", true)
			expect(heads).to.be.ok()
			local plaques, pieces = 0, 0
			-- DESCENDANTS: a mount is a Folder of its own since task 187, which is what lets the
			-- builder measure one and move the whole thing if it does not fit.
			for _, descendant in ipairs((heads :: Instance):GetDescendants()) do
				if descendant:IsA("BasePart") then
					local piece = descendant :: BasePart
					pieces += 1
					-- THE SHIELD'S BOARD **IS** THE PLAQUE, and since part 3b that is its name (part
					-- 3c). `shield` builds `<name>Board`, so counting the word "Plaque" counted zero
					-- -- another assertion that has not been able to pass since part 3b, hidden
					-- behind the two above it.
					if string.match(piece.Name, "Board$") then
						plaques += 1
					end
					-- THE BOUND IS THE INNER FACE PLUS THE OVERLAP THE ROWS ASK FOR (part 3c). A
					-- negative `standoff` pushes the board INTO the log bellies on purpose -- the
					-- Designer's rule everywhere in this spec is that a join overlaps and is never
					-- flush, because flush against a round log is a hairline gap at the belly and
					-- coplanar faces at the course joins. At `standoff = -0.2` and a 0.3 board the
					-- shield's centre sits 0.05 past the inner face, so a bound of the inner face
					-- EXACTLY is a test that cannot pass: it has been failing since part 3b.
					local lap = 0
					for _, row in ipairs(CFG.TROPHIES.MOUNTS) do
						lap = math.max(lap, -(row.standoff or 0))
					end
					local at = piece.Position
					expect(at.X <= room.centre.X + room.halfX + lap).to.equal(true)
					expect(at.X >= room.centre.X - room.halfX - lap).to.equal(true)
					expect(at.Z <= room.centre.Z + room.halfZ + lap).to.equal(true)
					expect(at.Z >= room.centre.Z - room.halfZ - lap).to.equal(true)
					-- ...and off the floor, and NOT THROUGH THE CEILING, which is the other half of
					-- that round: a 5.4-stud deer seated at its mount height stood 2.4 studs through
					-- a 7.4-stud room roof.
					--
					-- THE PART'S WHOLE EXTENT AND NOT ITS CENTRE (review round 1, note): an antler
					-- beam is a rotated cylinder whose top is a stud and a half above its middle, so
					-- a centre inside the room says nothing about the tine. This is the same box
					-- projection `Build.trophies` clamps with, which is what makes the clamp tested
					-- rather than asserted.
					local _, _, _, _, _, _, m10, m11, m12 = piece.CFrame:GetComponents()
					local reach = 0.5
						* (math.abs(m10) * piece.Size.X + math.abs(m11) * piece.Size.Y + math.abs(m12) * piece.Size.Z)
					expect(at.Y - reach > room.centre.Y).to.equal(true)
					expect(at.Y + reach <= room.centre.Y + room.height).to.equal(true)
				end
			end
			-- ONE SHIELD PER MOUNT. A MOUNT IS A BOARD AND AN ANIMAL SINCE TASK 196, and the animal
			-- is a Model handed in by the composition root -- so in a spec, which hands in none, a
			-- mount is exactly its board: the plaque and its point. What is asserted is the board,
			-- because that is the half this build is responsible for.
			expect(plaques).to.equal(#CFG.TROPHIES.MOUNTS)
			expect(pieces >= #CFG.TROPHIES.MOUNTS * 2).to.equal(true)
		end)

		it("hangs nothing on a wall in front of a window or the shop counter", function()
			-- A TROPHY ROW IS DATA, so the way it goes wrong is a row that names a wall something
			-- else already owns -- which is exactly what task 180 shipped: two heads on the back
			-- wall, one half inside the chimney and one behind the SHOP sign.
			local folder = Build.build(container, anchor, CFG, nil)
			local room = Build.roomFor(anchor, CFG)
			local heads = folder:FindFirstChild("Trophies", true) :: Instance
			local counter = folder:FindFirstChild(Data.COUNTER_NAME, true) :: BasePart
			for _, descendant in ipairs(heads:GetDescendants()) do
				if descendant:IsA("BasePart") and string.find(descendant.Name, "Plaque", 1, true) then
					local at = (descendant :: BasePart).Position
					-- NOT OVER THE COUNTER: the shield would be behind the SHOP sign.
					local overCounter = math.abs(at.X - counter.Position.X) < counter.Size.X / 2
						and math.abs(at.Z - counter.Position.Z) < 3
					expect(overCounter).to.equal(false)
					-- NOT IN A WINDOW, and a window is a RECTANGLE: a shield clashes only when it
					-- overlaps the opening BOTH along the wall and in height. A row above a window is
					-- a thing a lodge actually has.
					for _, row in ipairs(CFG.LODGE.WINDOWS) do
						local sameWall = (row.wall == "north" and at.Z > room.centre.Z + room.halfZ - 1)
							or (row.wall == "south" and at.Z < room.centre.Z - room.halfZ + 1)
							or (row.wall == "east" and at.X > room.centre.X + room.halfX - 1)
							or (row.wall == "west" and at.X < room.centre.X - room.halfX + 1)
						if sameWall then
							local along = if row.wall == "north" or row.wall == "south"
								then at.X - room.centre.X
								else at.Z - room.centre.Z
							local across = math.abs(along - row.along)
								< CFG.LODGE.WINDOW.WIDTH / 2 + CFG.TROPHIES.BOAR.PLAQUE.X / 2
							local high = at.Y - room.centre.Y
							local overlaps = high > CFG.LODGE.WINDOW.SILL_STUDS - CFG.TROPHIES.BOAR.PLAQUE.Y / 2
								and high < CFG.LODGE.WINDOW.SILL_STUDS + CFG.LODGE.WINDOW.HEIGHT
							expect(across and overlaps).to.equal(false)
						end
					end
				end
			end
		end)

		it("leaves no part of the lodge floating: every one of them touches another", function()
			-- THE TASK OWN WORDS: *"no floating parts (every part within the lodge bounds and
			-- supported)"*. A plaque hangs on a wall and a rafter hangs off a roof, so "supported"
			-- cannot mean "has ground under it"; what it can mean, and what this measures, is that
			-- every part of the building TOUCHES another part of the building -- and that all of them
			-- are inside the envelope the lodge is allowed to occupy.
			local folder = Build.build(container, anchor, CFG, nil)
			local lodge = folder:FindFirstChild("Lodge") :: Instance
			expect(lodge).to.be.ok()
			local origin = anchor + CFG.LODGE.OFFSET
			local boxes = {}
			for _, descendant in ipairs(lodge:GetDescendants()) do
				-- THE KEEPER IS A BODY AND NOT MASONRY: his limbs hang off his own joints.
				if descendant:IsA("BasePart") and descendant:FindFirstAncestorOfClass("Model") == nil then
					local piece = descendant :: BasePart
					-- THE ENVELOPE: the footprint plus the roof overhang and the chimney one side,
					-- the porch to the south, the ground below and the chimney pots above.
					local west = origin.X - CFG.LODGE.SIZE.X / 2 - CFG.LODGE.CHIMNEY.WIDTH - 2
					local east = origin.X + CFG.LODGE.SIZE.X / 2 + CFG.LODGE.ROOF.GABLE_STUDS + 2
					local south = origin.Z
						- CFG.LODGE.SIZE.Z / 2
						- CFG.LODGE.PORCH.DEPTH
						- CFG.LODGE.PORCH.STEPS * CFG.LODGE.PORCH.STEP_DEPTH
						- 2
					local north = origin.Z + CFG.LODGE.SIZE.Z / 2 + CFG.LODGE.ROOF.EAVE_STUDS + 2
					expect(piece.Position.X >= west and piece.Position.X <= east).to.equal(true)
					expect(piece.Position.Z >= south and piece.Position.Z <= north).to.equal(true)
					expect(piece.Position.Y >= origin.Y - 3).to.equal(true)
					expect(
						piece.Position.Y <= origin.Y + CFG.LODGE.RIDGE_STUDS + CFG.LODGE.CHIMNEY.ABOVE_RIDGE_STUDS + 4
					).to.equal(true)
					table.insert(boxes, piece)
				end
			end
			expect(#boxes > 200).to.equal(true)
			-- TOUCHING, measured as OVERLAPPING BOXES on all three axes with three quarters of a stud
			-- of slack -- loose enough for a rotated roof slab and tight enough to mean something.
			-- Round 1 used bounding SPHERES, and the plinth's sphere alone has a 22-stud radius, so
			-- nearly anything inside the envelope passed (review note). A box projected onto the
			-- world axes is still generous for a rotated part and is no longer generous about WHERE.
			local function extent(piece: BasePart): Vector3
				local cf = piece.CFrame
				local x, y, z = cf.RightVector, cf.UpVector, cf.LookVector
				local half = piece.Size / 2
				return Vector3.new(
					math.abs(x.X) * half.X + math.abs(y.X) * half.Y + math.abs(z.X) * half.Z,
					math.abs(x.Y) * half.X + math.abs(y.Y) * half.Y + math.abs(z.Y) * half.Z,
					math.abs(x.Z) * half.X + math.abs(y.Z) * half.Y + math.abs(z.Z) * half.Z
				)
			end
			local spans = {}
			for index, piece in ipairs(boxes) do
				spans[index] = extent(piece)
			end
			for index, piece in ipairs(boxes) do
				local touched = false
				for other, another in ipairs(boxes) do
					if another ~= piece then
						local gap = another.Position - piece.Position
						local reach = spans[index] + spans[other] + Vector3.new(0.75, 0.75, 0.75)
						if math.abs(gap.X) <= reach.X and math.abs(gap.Y) <= reach.Y and math.abs(gap.Z) <= reach.Z then
							touched = true
							break
						end
					end
				end
				if not touched then
					error(string.format("%s floats: nothing of the lodge is within reach of it", piece.Name), 0)
				end
			end
		end)

		it("keeps the fence line OUT of the yard, the porch, the spawn and the lodge, in BOTH builds", function()
			-- ROUND 2'S BLOCKING FINDING, as a case that fails without the fix. `POSTS_PER_SIDE = 9`
			-- from z -98 at 18 studs ran the WEST line (x +2, two studs off the lodge's centre line)
			-- to z +46 -- the lodge's own centre. One post stood inside the cabin through its
			-- floorboards, one in the middle of the porch beside the doorway, and a rail lay across
			-- the spawn pad at knee height. Nothing bounded it: the field rectangle is 110 studs away.
			--
			-- The bound is the YARD'S southern edge, because everything the fence must not reach --
			-- the yard, the circle, the porch, the spawn, the lodge -- is north of it. **IT IS ASKED
			-- OF `Build.yardRect` SINCE TASK 243** and not written as `OFFSET.Z - 22`: that literal
			-- was the old east-stepping yard's half-depth, and when the row turned south the real
			-- edge went from z +2 to z -44, leaving the bound 46 studs out of step with the sentence
			-- above it.
			for _, withModels in ipairs({ true, false }) do
				local templates = if withModels then fakeTemplates() else nil
				local folder = Build.build(container, anchor, CFG, templates)
				local room = Build.roomFor(anchor, CFG)
				local _, _, yardMidZ, yardHalfZ = Build.yardRect(anchor, CFG)
				local yardSouth = yardMidZ - yardHalfZ
				local fences = folder:FindFirstChild("Fences")
				expect(fences).to.be.ok()
				local pieces = 0
				for _, descendant in ipairs((fences :: Instance):GetDescendants()) do
					if descendant:IsA("BasePart") then
						pieces += 1
						local piece = descendant :: BasePart
						local north = piece.Position.Z + piece.Size.Z / 2
						expect(north <= yardSouth).to.equal(true)
						-- ...and, said the other way round, never in the room a player shops in.
						local insideX = math.abs(piece.Position.X - room.centre.X) < room.halfX
						local insideZ = math.abs(piece.Position.Z - room.centre.Z) < room.halfZ
						expect(insideX and insideZ).to.equal(false)
					end
				end
				expect(pieces > 0).to.equal(true)
				if templates then
					(templates :: Instance):Destroy()
				end
			end
		end)

		it("leaves every pad's SURFACE above the yard slab, and its underside below the shelf", function()
			-- TASK 177 ROUND 1 BURIED THE CIRCLE. `road` lays its slabs on the shelf and the yard
			-- covers the whole row of bays, so a ring lifted 0.08 studs off the SHELF sat 0.42 studs
			-- inside an opaque slab: a sign reading "STAND HERE TO HUNT" with nothing to stand in.
			-- Task 182 SINKS the pad instead -- its top above every slab, its bottom below the
			-- terrain -- so neither failure is reachable, and this measures both ends.
			local folder = Build.build(container, anchor, CFG, fakeTemplates())
			local yard = folder:FindFirstChild("Yard", true) :: BasePart
			expect(yard).to.be.ok()
			local surface = yard.Position.Y + yard.Size.Y / 2
			local shelf = anchor.Y
			for index = 1, CFG.TRUCK.COUNT do
				local deck = folder:FindFirstChild(Data.padPartName(index) :: string, true) :: BasePart
				expect(deck).to.be.ok()
				local top = deck.Position.Y + deck.Size.Y / 2
				expect(top >= surface).to.equal(true)
				-- NOTHING FLOATS: the underside is under the shelf, so there is no visible edge.
				expect(deck.Position.Y - deck.Size.Y / 2 < shelf).to.equal(true)
				-- AND THE GLOWING RIM STANDS ON THAT SURFACE rather than inside it, which is the
				-- same mistake one layer up.
				local rim = deck.Parent :: Instance
				local bars = 0
				for _, child in ipairs(rim:GetChildren()) do
					if string.sub(child.Name, 1, 3) == "Rim" then
						bars += 1
						local piece = child :: BasePart
						expect(piece.Position.Y - piece.Size.Y / 2 >= top - 1e-4).to.equal(true)
						expect(piece.Material).to.equal(Enum.Material.Neon)
					end
				end
				expect(bars).to.equal(4)
			end
		end)
	end)

	describe("where he stands when he arrives", function()
		local anchor = Vector3.new(0, 100, 0)

		it("can never put a player off the lobby's own field, however high the index climbs", function()
			-- REVIEW ROUND 1, FINDING 3, AND IT IS THE CASE THAT FAILS ON THE OLD CODE. The caller's
			-- index is a counter that only ever goes up -- one per player who has ever joined -- and
			-- unwrapped it is `floor((index + 1) / 2) * SPREAD_STUDS` studs off the middle with no
			-- bound at all: index 37 is 114 studs, outside `FIELD.SPAN_STUDS`'s half-span of 110. The
			-- man then stands exactly where `world.place` put him, `Join.insideField` answers FALSE,
			-- `Join.needsReturn` answers true, and the lobby re-places him at the same off-shelf point
			-- every `RETURN_COOLDOWN_SECONDS` for ever.
			-- THE BOUND IS THE PORCH HE LANDS ON, not the lodge behind it (task 187): the deck is
			-- the footprint less `PORCH.INSET_STUDS` either side, and a slot outside that is a man
			-- standing on the corner of his own steps.
			local half = CFG.LODGE.SIZE.X / 2 - CFG.LODGE.PORCH.INSET_STUDS
			for index = 0, 200 do
				local at = Lobby.spawnCFrame(anchor, index, CFG).Position
				-- Inside the field, which is the rule that closes the respawn loop...
				expect(Join.insideField(at, anchor, CFG)).to.equal(true)
				-- ...and inside the lodge's own front, which is the porch the design names.
				expect(math.abs(at.X - (anchor.X + CFG.SPAWN.OFFSET.X)) < half).to.equal(true)
			end
			-- The slots WRAP rather than widen: index 0 and index SLOTS are the same place.
			local first = Lobby.spawnCFrame(anchor, 0, CFG).Position
			local wrapped = Lobby.spawnCFrame(anchor, CFG.SPAWN.SLOTS, CFG).Position
			expect((first - wrapped).Magnitude < 1e-4).to.equal(true)
		end)

		it("spreads two players more than a body apart, and faces them north", function()
			local first = Lobby.spawnCFrame(anchor, 0, CFG)
			local second = Lobby.spawnCFrame(anchor, 1, CFG)
			expect((first.Position - second.Position).Magnitude >= 4).to.equal(true)
			-- +Z: he looks at the lodge with the forest behind its roof, and the truck is to his
			-- right. Karen's *"house is in fields next to forrest"* read as a camera angle.
			expect(first.LookVector.Z > 0.99).to.equal(true)
			-- Centre-out, so a solo player gets the middle of the porch.
			expect(math.abs(first.Position.X - (anchor.X + CFG.SPAWN.OFFSET.X)) < 1e-4).to.equal(true)
		end)
	end)

	-- ---------------------------------------------------------------- the shopkeeper (task 181)
	--
	-- KAREN, 2026-10-14: *"in lobby has to be a person bot who you need to click E to get access to
	-- shop"*. Since this task took task 178's auto-open away, the prompt on this body is THE ONLY
	-- WAY INTO THE SHOP -- so "is there a man there, and has he got a prompt on him" is the one
	-- assertion in this file whose missing answer makes the shop unopenable.
	describe("the shopkeeper behind the counter", function()
		local container, folder
		local seen: { model: Model?, team: string?, look: any } = { model = nil, team = nil, look = nil }

		beforeEach(function()
			seen = { model = nil, team = nil, look = nil }
			container = Instance.new("Folder")
			container.Name = "LobbyKeeperSpecWorld"
			container.Parent = Workspace
			local made = Build.build(container, Vector3.new(0, 100, 0), CFG, nil, {
				rig = fakeRig,
				dress = function(model: Model, team: string, _config, look): boolean
					seen.model = model
					seen.team = team
					seen.look = look
					return true
				end,
				dressConfig = { fake = true },
			})
			folder = made
		end)

		afterEach(function()
			container:Destroy()
		end)

		it("stands one man behind the till, and counts him", function()
			local body = folder:FindFirstChild(Data.KEEPER_NAME, true)
			expect(body).to.be.ok()
			expect((body :: Instance):IsA("Model")).to.equal(true)
			expect(Build.stats().keepers).to.equal(1)
			-- UNDER THE SHOP, with the counter and the sign: one place in the tree to look for the
			-- whole shop, which is what `Lobby.counterPart` and `Lobby.shopPrompt` rest on.
			local shop = folder:FindFirstChild("Shop", true)
			expect(shop).to.be.ok()
			expect((body :: Instance):IsDescendantOf(shop :: Instance)).to.equal(true)
			-- BEHIND the counter and not in it: further from the room by `BEHIND_STUDS`, and
			-- standing on the same floor.
			local counter = folder:FindFirstChild(Data.COUNTER_NAME, true) :: BasePart
			local root = (body :: Model).PrimaryPart :: BasePart
			expect(math.abs(root.Position.X - counter.Position.X) < 1e-3).to.equal(true)
			local behind = root.Position.Z - counter.Position.Z
			expect(math.abs(behind - CFG.LODGE.KEEPER.BEHIND_STUDS) < 1e-3).to.equal(true)
			expect(root.Position.Y > counter.Position.Y).to.equal(true)
		end)

		it("cannot be pushed, cannot be walked into, and cannot stop a pellet", function()
			local body = folder:FindFirstChild(Data.KEEPER_NAME, true) :: Model
			local root = body.PrimaryPart :: BasePart
			-- THE ROOT IS ANCHORED AND THE LIMBS ARE NOT: `Bots.Rig.place(.., anchored = true)`'s
			-- arrangement. The anchor is what stops anything nudging him off his spot; the limbs
			-- stay on their joints so the idle clip can move them.
			expect(root.Anchored).to.equal(true)
			local parts = 0
			for _, descendant in ipairs(body:GetDescendants()) do
				if descendant:IsA("BasePart") then
					parts += 1
					expect(descendant.CanCollide).to.equal(false)
					-- `CanQuery = false` IS LOAD-BEARING and is this file's own rule everywhere else
					-- in the lobby: a body that stops a pellet changes what the shot hit.
					expect(descendant.CanQuery).to.equal(false)
					expect(descendant.CanTouch).to.equal(false)
					if descendant ~= root then
						expect(descendant.Anchored).to.equal(false)
					end
				end
			end
			expect(parts >= 4).to.equal(true)
		end)

		it("carries the prompt, with Karen's key, 8 studs and line of sight", function()
			local prompt = folder:FindFirstChild(Data.PROMPT_NAME, true)
			expect(prompt).to.be.ok()
			expect((prompt :: Instance):IsA("ProximityPrompt")).to.equal(true)
			local p = prompt :: ProximityPrompt
			local want = CFG.LODGE.KEEPER.PROMPT
			expect(p.KeyboardKeyCode).to.equal(want.KEYBOARD_KEY)
			expect(p.KeyboardKeyCode).to.equal(Enum.KeyCode.E) -- Karen's word, written twice on purpose
			expect(p.GamepadKeyCode).to.equal(want.GAMEPAD_KEY)
			expect(p.MaxActivationDistance).to.equal(want.MAX_DISTANCE)
			expect(p.MaxActivationDistance).to.equal(8) -- the Director's number, written twice on purpose
			expect(p.HoldDuration).to.equal(0) -- a tap, not a hold
			expect(p.RequiresLineOfSight).to.equal(true)
			-- A THUMB CAN REACH IT (task 220). `ProximityPrompt.ClickablePrompt` defaults to TRUE
			-- and `Build.shopPrompt` never sets it -- MEASURED on 2026-10-21, a fresh
			-- `Instance.new("ProximityPrompt")` in DEV Edit, which is what let the mobile task build
			-- NO interact button at all. Asserted here on the prompt the real `Build` makes in the
			-- real place rather than on a remembered default: one property is all that stands
			-- between a phone player and the shop.
			expect(p.ClickablePrompt).to.equal(true)
			expect(p.ActionText).to.equal("Shop")
			expect(p.ObjectText).to.equal("Press E")
			expect(p.Enabled).to.equal(true)
			-- ON THE COUNTER, IN FRONT OF THE CLIP, AND THAT IS A MEASUREMENT (task 195).
			-- `CanQuery = false` is IGNORED while `CanCollide` is true -- four parts, one per
			-- combination, each shot at with a ray in the live place: collide+query HIT,
			-- **collide+noquery HIT**, nocollide+query HIT, nocollide+noquery passed through. So
			-- the clip that stops a player vaulting the till also stops the prompt's own sight
			-- ray, and with the prompt on the keeper BEHIND it the shop could not be opened at
			-- all ("sight blocked by CounterGuard", measured at 1.5, 3 and 5 studs back).
			local at = p.Parent
			expect(at).to.be.ok()
			expect((at :: Instance):IsA("Attachment")).to.equal(true)
			local counter = folder:FindFirstChild(Data.COUNTER_NAME, true) :: BasePart
			expect((at :: Attachment).Parent).to.equal(counter)
			-- SOUTH OF THE CLIP'S OWN SLAB, which is the whole reason it moved: the clip's front
			-- face is the counter's customer face, so the prompt has to be in front of BOTH.
			local guard = folder:FindFirstChild("CounterGuard", true) :: BasePart
			local promptZ = counter.Position.Z + (at :: Attachment).Position.Z
			expect(promptZ < guard.Position.Z - guard.Size.Z / 2).to.equal(true)
			-- ...AND ABOVE THE TILL'S TOP, so it reads as the shop and not as a floating word.
			local floorY = Build.roomFor(Vector3.new(0, 100, 0), CFG).centre.Y
			local promptY = counter.Position.Y + (at :: Attachment).Position.Y
			expect(promptY > floorY + CFG.LODGE.COUNTER.Y + 0.35).to.equal(true)
			-- THE CUSTOMER'S FLOOR, which is the number that means anything: a man standing eight
			-- studs out from the counter's face is still inside the prompt, because it is measured
			-- from the counter now and not from the man behind it.
			expect(want.MAX_DISTANCE - CFG.LODGE.KEEPER.PROMPT_OUT_STUDS >= 7).to.equal(true)
			-- AND THERE IS A MAN BEHIND IT. The prompt is only built when there is one.
			local body = folder:FindFirstChild(Data.KEEPER_NAME, true) :: Model
			expect(body).to.be.ok()
			expect((body.PrimaryPart :: BasePart).Position.Z > counter.Position.Z).to.equal(true)
		end)

		it("is dressed by the outfit owner and by nothing else", function()
			-- ONE DRESSING PATH IN THIS REPOSITORY: `Build` hands a MODEL and a TEAM to the seam the
			-- composition root filled with `Match.Body.dress`, and learns nothing about outfits.
			expect(seen.model).to.be.ok()
			expect(seen.team).to.equal(CFG.LODGE.KEEPER.TEAM)
			expect(seen.look.hatColor).to.equal(CFG.LODGE.KEEPER.HAT_COLOR)
			expect(Build.stats().keeperDressed).to.equal(1)
		end)

		-- ...AND THE LOOK IS A WORD THAT OWNER ACTUALLY KNOWS. Task 181 round 1 shipped `"Hunter"`,
		-- which matched no row in `Body.OUTFITS`, so `Body.dress` returned early at *"nothing to
		-- wear"* and the keeper stood at the counter in default grey. The assertion above could not
		-- see it: it compared the config with itself.
		--
		-- SINCE TASK 196 THE WORD IS `Keeper` AND IT IS NOT A TEAM. Karen: *"improve bot visual for
		-- shopper nice hat ect"* -- he wears a loden suit, a felt hat with a band and a brush, and a
		-- waistcoat, which is a row in the players' own outfit table and not a second dressing path.
		it("hands over a look the outfit owner has an outfit for, and it is not a player's", function()
			local Body = Match.Body
			expect(Body.outfitFor(CFG.LODGE.KEEPER.TEAM, Match.CONFIG)).to.be.ok()
			expect(Body.baseFor(CFG.LODGE.KEEPER.TEAM, Match.CONFIG)).to.be.ok()
			-- NOT A TEAM ANYBODY CAN BE ON: `Match.Roster` deals in `Shooters` and `Drivers`, so a
			-- keeper's look can never be handed to a player by a team swap.
			expect(CFG.LODGE.KEEPER.TEAM).never.to.equal(Body.ROLE_WORDS.hunter)
			expect(CFG.LODGE.KEEPER.TEAM).never.to.equal(Body.ROLE_WORDS.beater)
			-- HE WEARS A HAT AND A WAISTCOAT, and the waistcoat is the piece no player has.
			local slots = {}
			for _, group in ipairs(Body.outfitFor(CFG.LODGE.KEEPER.TEAM, Match.CONFIG).parts) do
				slots[group.slot] = true
			end
			expect(slots[Body.SLOTS.hat]).to.equal(true)
			-- `PLATE_SLOTS` AND NOT `SLOTS` SINCE REVIEW ROUND 2: a waistcoat is plates this game
			-- builds, with no accessory behind it, and `SLOTS` means the slots the asset pipeline
			-- must have a key for.
			expect(slots[Body.PLATE_SLOTS.waistcoat]).to.equal(true)
			expect(slots[Body.SLOTS.vest]).to.equal(nil)
		end)

		-- `keeperDressed` MEANS THE OUTFIT OWNER SAID YES, not "the call did not throw" (review
		-- round 1, finding 2). It said `dressed=true` on the console over an undressed man.
		it("counts him as dressed only when the outfit owner says so", function()
			local bare = Instance.new("Folder")
			bare.Name = "LobbyUndressedSpecWorld"
			bare.Parent = Workspace
			Build.build(bare, Vector3.new(0, 100, 0), CFG, nil, {
				rig = fakeRig,
				dress = function(): boolean
					return false -- "there was nothing I could put on him"
				end,
			})
			expect(Build.stats().keepers).to.equal(1)
			expect(Build.stats().keeperDressed).to.equal(0)
			bare:Destroy()
		end)

		it("builds the lodge anyway when no body comes back", function()
			-- A SPEC THAT HAS NOT ASKED FOR A BODY DOES NOT GET ONE, which is what keeps the avatar
			-- service out of this harness -- and a source that answers nil is a lodge with nobody in
			-- it, never a lobby that failed to build.
			local bare = Instance.new("Folder")
			bare.Name = "LobbyNoKeeperSpecWorld"
			bare.Parent = Workspace
			local made = Build.build(bare, Vector3.new(0, 100, 0), CFG)
			expect(made:FindFirstChild(Data.KEEPER_NAME, true)).to.equal(nil)
			expect(made:FindFirstChild(Data.COUNTER_NAME, true)).to.be.ok()
			expect(Build.stats().keepers).to.equal(0)
			local nilled = Build.build(bare, Vector3.new(0, 100, 0), CFG, nil, {
				rig = function(): Model?
					return nil
				end,
			})
			expect(nilled:FindFirstChild(Data.KEEPER_NAME, true)).to.equal(nil)
			expect(Build.stats().keepers).to.equal(0)
			bare:Destroy()
		end)

		-- THE FLAG, READ AT THE ROOT AND PASSED INWARD, decides one thing here: whether the prompt is
		-- live. With `SHOP` off the panel is dead, and a "Press E" over a man who answers nothing is
		-- worse than no prompt.
		it("hangs a DEAD prompt on him when the shop is not in this build", function()
			local off = Instance.new("Folder")
			off.Name = "LobbyShopOffSpecWorld"
			off.Parent = Workspace
			local made = Build.build(off, Vector3.new(0, 100, 0), CFG, nil, { rig = fakeRig, shopOn = false })
			local prompt = made:FindFirstChild(Data.PROMPT_NAME, true) :: ProximityPrompt
			expect(prompt).to.be.ok()
			expect(prompt.Enabled).to.equal(false)
			-- ...and the MAN is still there. He is scenery as well as a door, and a lodge that
			-- empties itself when a flag goes off is a second thing for Karen to notice.
			expect(made:FindFirstChild(Data.KEEPER_NAME, true)).to.be.ok()
			off:Destroy()
		end)

		it("has a face, and a head that is not solid black", function()
			-- KAREN, 2026-10-14: *"person inside broken"*, and the probe said why: RGB 0,0,0 and no
			-- features. `Match.Body.paint` deliberately never writes `HeadColor3` -- *"the head is
			-- the player's own"* (design M5) -- which is right for a player and leaves a man built
			-- from an EMPTY `HumanoidDescription` with the head that description ships. He is not a
			-- player, so the LODGE gives him one, and it writes EVERY `BodyColors` on him for the
			-- reason `Body.paint` writes every one of them.
			local body = Build.keeper() :: Model
			expect(body).to.be.ok()
			local head = body:FindFirstChild("Head") :: BasePart
			expect(head).to.be.ok()
			expect(head.Color).to.equal(CFG.LODGE.KEEPER.SKIN_COLOR)
			local painted = 0
			for _, child in ipairs(body:GetChildren()) do
				if child:IsA("BodyColors") then
					painted += 1
					expect((child :: BodyColors).HeadColor3).to.equal(CFG.LODGE.KEEPER.SKIN_COLOR)
				end
			end
			expect(painted > 0).to.equal(true)
			local look = head:FindFirstChildOfClass("Decal")
			expect(look).to.be.ok()
			expect((look :: Decal).Texture).to.equal(CFG.LODGE.KEEPER.FACE_TEXTURE)
			-- AN ENGINE ASSET, NOT AN UPLOAD AND NOT A FETCH: `rbxasset://` is a file that ships
			-- with Studio, which is the whole reason this is allowed to be a texture at all.
			expect(string.sub((look :: Decal).Texture, 1, 11)).to.equal("rbxasset://")
		end)

		it("holds no script anywhere in his body", function()
			local body = folder:FindFirstChild(Data.KEEPER_NAME, true) :: Model
			for _, descendant in ipairs(body:GetDescendants()) do
				expect(descendant:IsA("LuaSourceContainer")).to.equal(false)
			end
		end)

		-- THE HEAD TURN, AND THE EPSILON IS THE POINT. The owner decides who he looks at on the scan
		-- it already runs; this writes it -- and a write per scan for a man standing still would be
		-- the bug `Lobby.stats().keeperTurns` exists to show.
		it("turns to the nearest man, and writes nothing when he has not moved", function()
			local body = folder:FindFirstChild(Data.KEEPER_NAME, true) :: Model
			local here = (body.PrimaryPart :: BasePart).Position
			-- Somebody standing well off to one side: that is a turn.
			local side = here + Vector3.new(10, 0, -4)
			expect(Build.faceKeeper(side, CFG)).to.equal(true)
			expect((body.PrimaryPart :: BasePart).CFrame.LookVector.X > 0.5).to.equal(true)
			-- ...and asking again for the same man writes nothing.
			expect(Build.faceKeeper(side, CFG)).to.equal(false)
			-- A man beyond `FACE_STUDS` is not a man he turns to: he goes back to facing the room.
			local far = here + Vector3.new(CFG.LODGE.KEEPER.FACE_STUDS + 20, 0, 0)
			expect(Build.faceKeeper(far, CFG)).to.equal(true)
			expect((body.PrimaryPart :: BasePart).CFrame.LookVector.Z < -0.99).to.equal(true)
			expect(Build.faceKeeper(nil, CFG)).to.equal(false)
		end)

		-- THE CLIENT'S OWN READER, against a lobby built where it actually looks. It is the only
		-- route the panel has to the prompt, so a renamed part or a prompt on the wrong instance is
		-- a shop nobody can open -- and `Workspace.Lobby` is where the live server builds it.
		it("is found by `Lobby.shopPrompt`, the one reader the client has", function()
			local live = Build.build(Workspace, Vector3.new(0, 100, 0), CFG, nil, { rig = fakeRig })
			local prompt = Data.shopPrompt()
			expect(prompt).to.be.ok()
			expect((prompt :: Instance):IsDescendantOf(live)).to.equal(true)
			live:Destroy()
			-- AND THE CACHE DIES WITH THE INSTANCE (`Lobby.counterPart`'s own rule): a stale prompt
			-- would be a panel listening to a lodge that is not there any more.
			expect(Data.shopPrompt()).to.equal(nil)
		end)
	end)

	-- ------------------------------------------------- the inside, clean (task 195)
	--
	-- KAREN, 2026-10-15: *"you need to fix inside the cabin / it's broken there / you need to make
	-- nice inside and person not hanging and all things not hanging clean perfect ... and you can't
	-- go over the table"*.
	--
	-- WHAT THE PHOTOGRAPHS COULD NOT SAY AND THESE CASES CAN. Every defect this task fixed was
	-- invisible to the suite that passed task 187: a door leaf standing in the middle of the room
	-- 0.2 studs off the floor, a keeper 0.188 studs under the floorboards with his arm 1.182 studs
	-- inside the till, a sign 0.15 studs off the logs, two rack pegs 0.05 off their board, and a
	-- service side a player could simply walk round. None of them is a missing part or a wrong
	-- name, which is all the old cases could see, so this block measures BOXES.
	--
	-- Note: docs/research/2026-10-16-lodge-inside-clean.md
	describe("the inside is clean", function()
		local anchor = Vector3.new(0, 100, 0)
		local container, folder, room

		beforeEach(function()
			container = Instance.new("Folder")
			container.Name = "LobbyCleanSpecWorld"
			container.Parent = Workspace
			folder = Build.build(container, anchor, CFG, nil, {
				rig = fakeRig,
				dress = function(): boolean
					return true
				end,
			})
			room = Build.roomFor(anchor, CFG)
		end)

		afterEach(function()
			container:Destroy()
		end)

		-- A PART'S OWN BOX, PROJECTED ONTO THE WORLD AXES -- half-extents, the same expression the
		-- trophy cases use, so a rotated antler is measured by where it really reaches and not by
		-- its centre.
		local function reachOf(piece: BasePart): Vector3
			local _, _, _, m00, m01, m02, m10, m11, m12, m20, m21, m22 = piece.CFrame:GetComponents()
			return Vector3.new(
				0.5 * (math.abs(m00) * piece.Size.X + math.abs(m01) * piece.Size.Y + math.abs(m02) * piece.Size.Z),
				0.5 * (math.abs(m10) * piece.Size.X + math.abs(m11) * piece.Size.Y + math.abs(m12) * piece.Size.Z),
				0.5 * (math.abs(m20) * piece.Size.X + math.abs(m21) * piece.Size.Y + math.abs(m22) * piece.Size.Z)
			)
		end

		-- HOW FAR TWO BOXES ARE INTO EACH OTHER, as the SMALLEST of the three axis overlaps: a
		-- positive answer is interpenetration, zero is touching, a negative answer is the gap.
		local function overlapOf(a: BasePart, b: BasePart): number
			local ra, rb = reachOf(a), reachOf(b)
			local d = a.Position - b.Position
			return math.min(ra.X + rb.X - math.abs(d.X), ra.Y + rb.Y - math.abs(d.Y), ra.Z + rb.Z - math.abs(d.Z))
		end

		local function insideParts(): { BasePart }
			local inside = folder:FindFirstChild("Inside", true)
			expect(inside).to.be.ok()
			local pieces: { BasePart } = {}
			for _, descendant in ipairs((inside :: Instance):GetDescendants()) do
				if descendant:IsA("BasePart") then
					table.insert(pieces, descendant :: BasePart)
				end
			end
			return pieces
		end

		it("rests every part of the inside on the floor, a wall, the ceiling or another part", function()
			-- NOTHING HANGS, AS SIX COMPARISONS PER PART. A piece of the inside is held when its
			-- bottom IS the floorboards, when its box reaches a wall plane or the ceiling, or when
			-- it touches another piece of the inside -- all within 0.05 studs. What it may not do
			-- is stand in the air on its own, which is what the door leaf, the shop sign and two
			-- rack pegs were doing when Karen said *"all things not hanging"*.
			local TOL = 0.05
			local pieces = insideParts()
			-- A BOUND NOTHING SATISFIES IS A BOUND NOTHING PROVES: this room really is furnished.
			-- 40 AND NOT 100 SINCE TASK 196: fifteen drawn trophy mounts -- a hundred and fifty
			-- cylinders between them -- came off the walls at Karen's word, and what hangs there now
			-- is ONE plaque and an animal the composition root hands in (which a spec does not).
			expect(#pieces > 40).to.equal(true)
			local floorY = room.centre.Y
			local ceilingY = floorY + room.height
			for _, piece in ipairs(pieces) do
				local r = reachOf(piece)
				local low, high = piece.Position - r, piece.Position + r
				local held = math.abs(low.Y - floorY) <= TOL
					or low.X <= room.centre.X - room.halfX + TOL
					or high.X >= room.centre.X + room.halfX - TOL
					or low.Z <= room.centre.Z - room.halfZ + TOL
					or high.Z >= room.centre.Z + room.halfZ - TOL
					or high.Y >= ceilingY - TOL
				if not held then
					for _, other in ipairs(pieces) do
						if other ~= piece and overlapOf(piece, other) >= -TOL then
							held = true
							break
						end
					end
				end
				if not held then
					error(
						string.format(
							"%s hangs in the air: its bottom is %.3f with the floor at %.3f, and it touches nothing",
							piece.Name,
							low.Y,
							floorY
						),
						0
					)
				end
			end
		end)

		it("stands the seller's feet ON the floorboards, measured and not assumed", function()
			-- KAREN: *"person not hanging"*. `KEEPER.ROOT_HEIGHT` is 3 and this rig's root is 3.188
			-- studs over its soles (the live figure, in `FAKE_RIG_PARTS`), so placing him at
			-- `floorY + ROOT_HEIGHT` and stopping there buries him 0.188 studs -- which is exactly
			-- what the live place measured. THIS CASE FAILS ON THE OLD CODE. What makes it pass is
			-- the engine's own `Humanoid.HipHeight` and not a better constant, because the idle
			-- clip moves his legs and a body seated by the pose it was built in sank another 0.174
			-- studs the moment the animation started.
			local body = folder:FindFirstChild(Data.KEEPER_NAME, true) :: Model
			expect(body).to.be.ok()
			local lowest, lowName = math.huge, "?"
			for _, descendant in ipairs(body:GetDescendants()) do
				if descendant:IsA("BasePart") then
					local piece = descendant :: BasePart
					local bottom = piece.Position.Y - reachOf(piece).Y
					if bottom < lowest then
						lowest, lowName = bottom, piece.Name
					end
				end
			end
			if math.abs(lowest - room.centre.Y) > 0.05 then
				error(
					string.format(
						"the keeper's %s is at %.3f and the floorboards are at %.3f",
						lowName,
						lowest,
						room.centre.Y
					),
					0
				)
			end
		end)

		it("gives the seller more room than he can reach, whichever way he is turned", function()
			-- HE TURNS ON THE SPOT (`Build.faceKeeper`), so the arms that are at his sides when he
			-- faces the room swing FORWARD when he turns to a customer standing off to one side.
			-- The bound is therefore his horizontal RADIUS about his own root and not his depth --
			-- measured live at 2.423 studs, and measured here off the body that was actually built.
			local body = folder:FindFirstChild(Data.KEEPER_NAME, true) :: Model
			local root = body.PrimaryPart :: BasePart
			local radius = 0
			for _, descendant in ipairs(body:GetDescendants()) do
				if descendant:IsA("BasePart") then
					local piece = descendant :: BasePart
					local r = reachOf(piece)
					local d = piece.Position - root.Position
					local far = Vector2.new(math.abs(d.X) + r.X, math.abs(d.Z) + r.Z)
					radius = math.max(radius, far.Magnitude)
				end
			end
			expect(radius > 2).to.equal(true) -- a man, not a post
			local counter = folder:FindFirstChild(Data.COUNTER_NAME, true) :: BasePart
			local backFace = counter.Position.Z + counter.Size.Z / 2
			local wallZ = room.centre.Z + room.halfZ
			if root.Position.Z - backFace < radius then
				error(
					string.format(
						"the keeper reaches %.3f studs and has %.3f to the till",
						radius,
						root.Position.Z - backFace
					),
					0
				)
			end
			if wallZ - root.Position.Z < radius then
				error(
					string.format(
						"the keeper reaches %.3f studs and has %.3f to the back wall",
						radius,
						wallZ - root.Position.Z
					),
					0
				)
			end
		end)

		it("lets no two pieces of furniture into each other", function()
			-- A THING THAT HANGS ON OR IN ANOTHER THING IS NOT A THING THAT FLOATS, and the
			-- opposite holds too: the chimney breast through the ceiling boards, the fire logs in
			-- the firebox and a lantern's rod into the planks are all CORRECT, and were measured as
			-- such. What is not correct is two separate pieces of furniture occupying the same air,
			-- so this case names the pieces and compares only pieces that are not the same piece.
			local keeper = folder:FindFirstChild(Data.KEEPER_NAME, true)
			local function groupOf(piece: BasePart): string?
				if keeper ~= nil and piece:IsDescendantOf(keeper :: Instance) then
					return "Shopkeeper"
				end
				local name = piece.Name
				if string.match(name, "^Counter") then
					return "Counter" -- the till, its cap, the wing, the return and the two clips
				elseif string.match(name, "^GunRack") then
					return "GunRack"
				elseif name == "Rug" then
					return "Rug"
				end
				return nil
			end
			local pieces: { BasePart } = {}
			local groups: { string } = {}
			local seen: { [string]: boolean } = {}
			for _, piece in ipairs(insideParts()) do
				local group = groupOf(piece)
				if group ~= nil then
					table.insert(pieces, piece)
					table.insert(groups, group)
					seen[group] = true
				end
			end
			-- EVERY PIECE THIS CASE CLAIMS TO WATCH IS REALLY THERE.
			-- THE TABLE AND ITS TWO BENCHES LEFT THE LIST IN TASK 196 PART 3D, with the furniture.
			-- Karen, 2026-10-16: *"remove table and all boar heads only keep one where is on
			-- fireplace"*. What is left is what is still in the room.
			for _, want in ipairs({ "Counter", "GunRack", "Rug", "Shopkeeper" }) do
				expect(seen[want]).to.equal(true)
			end
			for i = 1, #pieces do
				for j = i + 1, #pieces do
					if groups[i] ~= groups[j] then
						local depth = overlapOf(pieces[i], pieces[j])
						if depth > 0.05 then
							error(
								string.format(
									"%s (%s) is %.3f studs inside %s (%s)",
									pieces[i].Name,
									groups[i],
									depth,
									pieces[j].Name,
									groups[j]
								),
								0
							)
						end
					end
				end
			end
		end)

		it("lays the rug ON the floorboards", function()
			local rug = folder:FindFirstChild("Rug", true) :: BasePart
			expect(rug).to.be.ok()
			expect(math.abs((rug.Position.Y - rug.Size.Y / 2) - room.centre.Y) < 1e-4).to.equal(true)
			-- Cosmetic, like everything else in this room that is not walked on or walked into.
			expect(rug.CanCollide).to.equal(false)
			expect(rug.CanQuery).to.equal(false)
		end)

		it("closes the service side: a body can neither walk in nor jump in", function()
			-- KAREN: *"you can't go over the table"*. The bay behind the counter is bounded by the
			-- north wall, the east wall and TWO faces a body could cross -- the counter's customer
			-- face and the return's west face. This samples both planes on a half-stud grid from
			-- the floorboards to the ceiling and fails unless every sample is inside something
			-- solid: the till and its wing below, the return beside it, and the clips above.
			local counter = folder:FindFirstChild(Data.COUNTER_NAME, true) :: BasePart
			local solids: { BasePart } = {}
			for _, descendant in ipairs(folder:GetDescendants()) do
				if descendant:IsA("BasePart") and (descendant :: BasePart).CanCollide then
					table.insert(solids, descendant :: BasePart)
				end
			end
			local function solidAt(point: Vector3): boolean
				for _, piece in ipairs(solids) do
					local near = piece.CFrame:PointToObjectSpace(point)
					if
						math.abs(near.X) <= piece.Size.X / 2 + 1e-3
						and math.abs(near.Y) <= piece.Size.Y / 2 + 1e-3
						and math.abs(near.Z) <= piece.Size.Z / 2 + 1e-3
					then
						return true
					end
				end
				return false
			end
			local frontZ = counter.Position.Z - counter.Size.Z / 2
			local westX = counter.Position.X - counter.Size.X / 2 - CFG.LODGE.SERVICE.RETURN_WIDTH
			local eastX = room.centre.X + room.halfX
			local northZ = room.centre.Z + room.halfZ
			local lowY, highY = room.centre.Y + 0.1, room.centre.Y + room.height - 0.1
			local step = 0.5
			local x = westX
			while x <= eastX + 1e-6 do
				local y = lowY
				while y <= highY do
					if not solidAt(Vector3.new(x, y, frontZ)) then
						error(string.format("the counter line has a hole at x %.2f, y %.2f", x, y), 0)
					end
					y += step
				end
				x += step
			end
			local z = frontZ
			while z <= northZ + 1e-6 do
				local y = lowY
				while y <= highY do
					if not solidAt(Vector3.new(westX, y, z)) then
						error(string.format("the counter west return has a hole at z %.2f, y %.2f", z, y), 0)
					end
					y += step
				end
				z += step
			end
			-- AND THE CLIPS ARE INVISIBLE TO EVERY RAY, which is what keeps a pellet honest and the
			-- keeper's `RequiresLineOfSight` prompt reachable across the till.
			for _, name in ipairs({ "CounterGuard", "CounterGuardWest" }) do
				local guard = folder:FindFirstChild(name, true) :: BasePart
				expect(guard).to.be.ok()
				expect(guard.CanCollide).to.equal(true)
				expect(guard.CanQuery).to.equal(false)
				expect(guard.CanTouch).to.equal(false)
				expect(guard.Transparency).to.equal(1)
			end
		end)

		it("leaves the doorway open: no leaf, and no door part inside the room", function()
			-- KAREN: *"doors can be open no doors"*. The leaf is gone
			-- (`backups/2026-10-16_task-195_door-leaf.txt`), and what is left of the door is in the
			-- SOUTH WALL, never standing in the room -- which is the test the old suite did not
			-- have and is why a leaf could drift 1.34 studs indoors unnoticed.
			expect(CFG.LODGE.DOOR.WIDTH >= 6).to.equal(true)
			expect((CFG.LODGE.DOOR :: any).LEAF_OPEN_RADIANS).to.equal(nil)
			local southInner = room.centre.Z - room.halfZ
			for _, descendant in ipairs(folder:GetDescendants()) do
				if descendant:IsA("BasePart") and string.match(descendant.Name, "^Door") then
					local piece = descendant :: BasePart
					expect(piece.Name).never.to.equal("DoorLeaf")
					local nearest = piece.Position.Z - reachOf(piece).Z
					if nearest > southInner + 0.05 then
						error(
							string.format("%s stands %.3f studs inside the room", piece.Name, nearest - southInner),
							0
						)
					end
				end
			end
		end)

		it("hangs the trophies in rows: two heights, and a wall's two rows in the same places", function()
			-- THE DIRECTOR'S *"even rows"*. Before this the east wall carried four plaques at 4.8
			-- and two at 8.2 on `along` values that matched neither row, and the north wall's boar
			-- hung at 5 between two roe at 4.8.
			-- WHAT THE EYE LINES UP IS THE TOP OF THE BOARD, NOT ITS CENTRE (part 3c). Since the
			-- Designer's wall (part 3b) a boar's shield and a sow's are different HEIGHTS -- 1.9
			-- against 1.44 of body -- so two shields whose centres share a `height` are visibly
			-- stepped, and two that LOOK level have centres 0.3 apart. The old case compared
			-- `mount.height` against two literals and therefore failed the moment the wall carried
			-- two sizes: it has been failing since part 3b, and it was testing the wrong number
			-- before that.
			local low, high = CFG.TROPHIES.HEIGHT_STUDS, CFG.TROPHIES.UPPER_STUDS
			expect(high > low).to.equal(true)
			local rows: { [string]: { number } } = {}
			for _, mount in ipairs(CFG.TROPHIES.MOUNTS) do
				local kind = CFG.TROPHIES[string.upper(mount.kind)]
				local top = (mount.height or low) + kind.BODY / 2
				rows[mount.wall] = rows[mount.wall] or {}
				table.insert(rows[mount.wall], top)
			end
			for wall, tops in pairs(rows) do
				table.sort(tops)
				-- AT MOST TWO ROWS A WALL, and every shield in a row level with the others to a
				-- tenth of a stud.
				local bands = 1
				for index = 2, #tops do
					if tops[index] - tops[index - 1] > 0.1 then
						bands += 1
					elseif tops[index] - tops[index - 1] > 1e-6 then
						-- same band: it has to be LEVEL, not merely close.
						error(
							string.format(
								"two shields on the %s wall sit %.3f studs apart, which reads as crooked",
								wall,
								tops[index] - tops[index - 1]
							),
							0
						)
					end
				end
				if bands > 2 then
					error(string.format("the %s wall hangs its trophies on %d rows, not two", wall, bands), 0)
				end
			end
		end)
	end)

	describe("the countdown the client reads", function()
		it("is nil in, nil out, and floors at zero", function()
			expect(Data.secondsLeft(nil, 100)).to.equal(nil)
			expect(Data.secondsLeft(105, 100)).to.equal(5)
			-- A past deadline is "now", never a negative number counting the wrong way.
			expect(Data.secondsLeft(90, 100)).to.equal(0)
		end)
	end)

	-- ---------------------------------------------------------------- task 197
	describe("the truck that starts while a party loads", function()
		it("is loading in exactly the three states after the pick, and in no other", function()
			-- THE ONE RULE WITH TWO READERS: the banner on a member's screen (`DHPadMine`) and the
			-- engine, lights and smoke on that pad's truck (`Build.setTruck`). They come up and go
			-- down together because they are the same fact said twice.
			local STATE = Data.PAD_STATE
			expect(Data.padLoading(STATE.FILLING)).to.equal(true)
			expect(Data.padLoading(STATE.COUNTDOWN)).to.equal(true)
			expect(Data.padLoading(STATE.LEAVING)).to.equal(true)
			-- `sizing` IS THE WHOLE BOUNDARY: a man reading the dialog has committed to nothing, and
			-- the Director's brief starts at *"the moment a size is picked"* -- the `sizing ->
			-- filling` edge exactly.
			expect(Data.padLoading(STATE.SIZING)).to.equal(false)
			expect(Data.padLoading(STATE.EMPTY)).to.equal(false)
			expect(Data.padLoading(nil)).to.equal(false)
			expect(Data.padLoading("Filling")).to.equal(false)
			expect(Data.padLoading(4 :: any)).to.equal(false)
			-- EVERY STATE THE MACHINE CAN BE IN IS ANSWERED, so a sixth state could not slip in
			-- unclassified: four of the five are named above and `Pads` has no other.
			local seen = 0
			for _, word in pairs(STATE) do
				if Data.padLoading(word) or word == STATE.SIZING or word == STATE.EMPTY then
					seen += 1
				end
			end
			expect(seen).to.equal(5)
		end)

		it("tells a lamp from a chassis, and a headlight from a tail light", function()
			-- PURE, AND THE TABLE IS THE MEASUREMENT. Every row below was dumped out of
			-- `Workspace.LobbyAssets.Truck` -- "PickUp Truck (Prop)", the free model four bays clone
			-- -- in the Forest Test on 2026-10-17, and the whole point of the size bound is the LAST
			-- row: the model's CHASSIS is a `Neon` part NAMED `Light`, 17.65 studs long. Without the
			-- bound, every truck would have had a SpotLight hung inside its own frame.
			local NEON = Enum.Material.Neon
			local function lamp(size: Vector3): boolean
				return Build.isTruckLamp("Light", NEON, size, CFG)
			end
			expect(lamp(Vector3.new(1.29, 1.12, 1.35))).to.equal(true) -- the headlights
			expect(Build.isTruckLamp("T", NEON, Vector3.new(0.4, 1, 0.66), CFG)).to.equal(true) -- a tail
			expect(Build.isTruckLamp("B", NEON, Vector3.new(0.36, 0.81, 0.2), CFG)).to.equal(true) -- a brake
			expect(Build.isTruckLamp("TS", NEON, Vector3.new(0.51, 0.32, 0.24), CFG)).to.equal(true) -- a blinker
			expect(lamp(Vector3.new(5.74, 0.59, 0.57))).to.equal(false) -- the 5.7-stud front bar
			expect(lamp(Vector3.new(6.72, 3.45, 6.15))).to.equal(false) -- a 6-stud blob
			expect(lamp(Vector3.new(6.7, 4.5, 17.65))).to.equal(false) -- THE CHASSIS
			-- ...AND NOTHING THAT IS NOT A LIGHT AT ALL IS A LAMP, however small it is.
			expect(Build.isTruckLamp("Color", Enum.Material.SmoothPlastic, Vector3.new(1, 1, 1), CFG)).to.equal(false)
			expect(Build.isTruckLamp("Windscreen", Enum.Material.Glass, Vector3.new(1, 1, 1), CFG)).to.equal(false)

			-- WHITE MEANS HEADLIGHT, and the three other hues on this model do not: their lowest
			-- channel is 61, 89 and 98 against a threshold of 0.75 (191 of 255).
			expect(Build.isHeadLamp(Color3.fromRGB(248, 248, 248), CFG)).to.equal(true)
			expect(Build.isHeadLamp(Color3.fromRGB(213, 115, 61), CFG)).to.equal(false) -- amber
			expect(Build.isHeadLamp(Color3.fromRGB(255, 89, 89), CFG)).to.equal(false) -- tail red
			expect(Build.isHeadLamp(Color3.fromRGB(190, 104, 98), CFG)).to.equal(false) -- brake red
			expect(Build.isHeadLamp(Color3.fromRGB(163, 162, 165), CFG)).to.equal(false) -- the shipped grey

			-- A TAIL IS IN THE FAR *QUARTER*, NOT MERELY THE FAR HALF (task 197 part 2, measured).
			-- The model's `B` at local x **+2.80** of a 9.2 half-length is the HIGH CENTRE BRAKE
			-- LIGHT ON THE CAB ROOF. A far-half test called it a tail, hung a red `PointLight` on
			-- the roof of every started truck, and the like-for-like night pair showed the two
			-- NEIGHBOURING trucks and the ground washed salmon pink by it.
			local behind = -9.2 * CFG.TRUCK.ENGINE.TAIL_MIN_FRACTION
			expect(2.80 < behind).to.equal(false) -- the roof lamp is NOT a tail
			expect(-8.53 < behind).to.equal(true) -- the real tails are (facing is -x in this frame)
			expect(-8.64 < behind).to.equal(true)
			-- ...AND THE FRONT AMBERS ARE NOWHERE NEAR IT, which is what keeps a red glow off a bonnet.
			expect(7.99 < behind).to.equal(false)

			-- AN UNLIT LAMP IS NOT EMISSIVE AT ALL. `Neon` with a dark colour still glows at night,
			-- which is how three unlit trucks came to look lit in the first frames -- so `setTruck`
			-- swaps the MATERIAL with the colour.
			expect(CFG.TRUCK.ENGINE.OFF_MATERIAL).never.to.equal(Enum.Material.Neon)
		end)

		it("cuts both engine clips inside what was measured, and keeps the loop out of the start", function()
			-- THE WINDOWS ARE MEASURED off the assets' own `PlaybackLoudness` (the research note's
			-- section 5), and these are the claims those numbers have to keep -- so a retune that
			-- moved a window back over the part of the recording where the engine STARTS or SHUTS
			-- DOWN would fail here rather than in Karen's ears.
			local E = CFG.TRUCK.ENGINE
			-- The command car is 10.87 s and revs from 3.4: the start has to end before that.
			expect(E.START_FROM).to.equal(0)
			expect(E.START_TO > 2).to.equal(true)
			expect(E.START_TO <= 3.4).to.equal(true)
			-- The Dodge Ram is 24.91 s, its own start runs to 6.0 and it fades from 24.0: the LOOP
			-- has to sit strictly inside the flat idle between them, or every pass re-starts the
			-- engine.
			expect(E.IDLE_FROM >= 6).to.equal(true)
			expect(E.IDLE_TO <= 23.8).to.equal(true)
			expect(E.IDLE_TO - E.IDLE_FROM >= 8).to.equal(true)
			-- ...AND THE IDLE IS THE LOUDER OF THE TWO BY GAIN, because it was recorded far quieter:
			-- equal volumes measured ~100-190 against ~15 and would have left silence under the
			-- banner, which is the thing this task exists to remove.
			expect(E.IDLE_VOLUME > E.START_VOLUME).to.equal(true)
			-- BOTH IDS ARE LIBRARY AUDIO AND NEITHER IS EMPTY: a truck with no voice is the silence
			-- Karen reported, and an empty id plays nothing without saying so.
			expect(string.match(E.START_SOUND_ID, "^rbxassetid://%d+$") ~= nil).to.equal(true)
			expect(string.match(E.IDLE_SOUND_ID, "^rbxassetid://%d+$") ~= nil).to.equal(true)
			-- THE SMOKE IS AN ENGINE TEXTURE (`rbxasset://`) and not an uploaded one, so it cannot
			-- 404 and cannot be moderated away.
			expect(string.sub(E.SMOKE_TEXTURE, 1, 11)).to.equal("rbxasset://")
			-- THE ENGINE CARRIES TO THE PORCH (46 studs) AND NOT ACROSS THE FIELD (220).
			expect(E.ROLL_OFF_MAX_STUDS > 46).to.equal(true)
			expect(E.ROLL_OFF_MAX_STUDS < 220).to.equal(true)
			expect(E.ROLL_OFF_MIN_STUDS < E.ROLL_OFF_MAX_STUDS).to.equal(true)
		end)

		it("gives the restyled dialog its words, its big buttons and a line for every row", function()
			-- KAREN: *"same with entering in game menu has to be nicer and cleaner"*. The WORDS and
			-- the PIXELS are data because both sides read them; what this case holds is that every
			-- row has a line, that the box still fits a phone, and that the rectangle the Hud builds
			-- is the one the panel computes.
			local PANEL = CFG.PADS.PANEL
			expect(PANEL.WIDTH <= 400).to.equal(true)
			-- 60 px ROWS, over the 44 Roblox sets as a touch minimum and inside the designer's 48-60.
			expect(PANEL.BUTTON_PX >= 48).to.equal(true)
			expect(PANEL.BUTTON_PX <= 60).to.equal(true)
			expect(PANEL.ROW_PX >= PANEL.BUTTON_PX).to.equal(true)
			-- THE HEADER IS THE SHOP HEADER'S OWN 64, so the two panels are one header drawn twice.
			expect(PANEL.HEADER_PX).to.equal(64)
			expect(#PANEL.TITLE > 0).to.equal(true)
			expect(#PANEL.HINT > 0).to.equal(true)
			-- THE EYEBROW CARRIES WHICH TRUCK, so it has to take the number.
			expect(string.format(PANEL.EYEBROW, 3)).to.equal("TRUCK 3")
			-- EVERY ROW HAS ITS SHORT LINE (the Director: *"a short line each"*), and the label is
			-- still Karen's own `1 / 1` with the word moved off it.
			for _, row in ipairs(CFG.PADS.SIZES) do
				expect(type(row.note)).to.equal("string")
				expect(#row.note > 0).to.equal(true)
				expect(string.find(row.label, "/", 1, true) ~= nil).to.equal(true)
			end
			-- THE BANNER'S FOUR LINES, one per loading state plus its title, and the countdown takes
			-- a number.
			local WORDS = CFG.PADS.LEAVING
			expect(#WORDS.TITLE > 0).to.equal(true)
			expect(#WORDS.FILLING > 0).to.equal(true)
			expect(#WORDS.GOING > 0).to.equal(true)
			expect(string.find(string.format(WORDS.COUNTDOWN, 4), "4", 1, true) ~= nil).to.equal(true)
			-- THE BANNER'S EYEBROW CARRIES NO NUMBER, and this case is the live defect written down:
			-- the first banner in the Forest Test read TRUCK 1 over a player standing on pad 2,
			-- because `Lobby.padAsking` only answers during `sizing` and the banner is up afterwards.
			-- A format specifier here would be the screen claiming to know what the world never told
			-- it (`Objective.CONFIG.TEXT`'s own rule). The DIALOG's eyebrow keeps its number, because
			-- that one is up exactly when the client has been told the index.
			expect(string.find(WORDS.EYEBROW, "%%", 1, true)).to.equal(nil)
			expect(#WORDS.EYEBROW > 0).to.equal(true)
			-- IT IS FULL WIDTH LESS A MARGIN, AND CAPPED, and it sits under the middle of the screen.
			expect(WORDS.MARGIN_PX > 0).to.equal(true)
			expect(WORDS.MAX_WIDTH >= PANEL.WIDTH).to.equal(true)
			expect(WORDS.Y_SCALE > 0.5).to.equal(true)
			expect(WORDS.Y_SCALE < 1).to.equal(true)
			-- **THE UPPER BOUND USED TO BE 0.85 AND ITS STATED REASON WAS MEASURED FALSE** (task 209
			-- round 2). It read *"clear of the bottom rail"*; the rail is not at the bottom. Measured
			-- live in the Forest Test with the dialog and the banner both up, on a 955 x 785 client:
			-- `Rail` is x[895..943] y[240..344] -- a column down the RIGHT EDGE at mid height -- and
			-- the banner is x[198..758], which never reaches it in x at any height. What the banner
			-- actually has to clear is the SIZE DIALOG, which it did not: at 0.68 they overlapped by
			-- 96 px on a 400x800 screen and 110 px on 1280x720, which was round 1's blocking finding.
			--
			-- THAT RULE IS HELD WHERE IT CAN BE MEASURED RATHER THAN RESTATED. It needs the dialog's
			-- own drawn height (`PadPanel.heightFor()`, a client module this server spec cannot
			-- require) and it has to hold at more than one viewport, so it lives in
			-- `tests/client/pad_panel.spec.luau`, *"never draws the click's banner across the size
			-- dialog (task 209 round 2)"*, which reads the LIVE frames at 400x800 and at 1280x720.
			-- Copying the arithmetic here would be a second answer to "where is the banner".
			-- ...AND THE RAIL STAYS PRESSABLE OVER BOTH (16 is `Rail.CONFIG.Z_INDEX`).
			expect(WORDS.Z_INDEX < 16).to.equal(true)
			expect(PANEL.Z_INDEX < 16).to.equal(true)
		end)
	end)

	-- ----------------------------------------------------------- THE ROLE SWITCH (task 229)
	--
	-- KAREN, 2026-10-21: *"we also need to have posibility to choose once you have a card always
	-- hunter maybe sometimes I want to be a beater we need to find a way to do that"*.
	--
	-- THE PURE HALF ONLY: the whitelist and the level rule, with no world, no player and no clock.
	-- The DOOR, the bucket, the reset on the scan and the frozen memo are driven against fakes in
	-- `tests/server/lobby_live.spec.luau`, which is the spec that starts this owner.
	-- Design: docs/design/role-switch.md (sections 3, 6, 15.3)
	describe("the role a man asks for, for one drive", function()
		it("knows exactly two words", function()
			-- ONE WHITELIST, asked by the server's door and by the client's sender, so *"which words
			-- are legal"* has one answer -- `Pads.sizeAllowed`'s rule applied to a string.
			expect(Data.roleAllowed(Data.ROLE_WISH.HUNTER)).to.equal(true)
			expect(Data.roleAllowed(Data.ROLE_WISH.BEATER)).to.equal(true)
			for _, bad in ipairs({
				"HUNTER",
				"Beater",
				"shooter",
				"drivers",
				"",
				" hunter",
			}) do
				expect(Data.roleAllowed(bad)).to.equal(false)
			end
			for _, bad in ipairs({ 1, true, {} }) do
				expect(Data.roleAllowed(bad)).to.equal(false)
			end
			expect(Data.roleAllowed(nil)).to.equal(false)
			-- THE TWO WORDS ARE FROZEN AND ARE DISTINCT, and the attribute's name is one string
			-- beside `DHPadMine` -- `Lobby` is the only writer of either.
			expect(table.isfrozen(Data.ROLE_WISH)).to.equal(true)
			expect(Data.ROLE_WISH.HUNTER).never.to.equal(Data.ROLE_WISH.BEATER)
			expect(Data.ROLE_WISH_ATTRIBUTE).to.equal("DHRoleWish")
			expect(Data.ROLE_REQUEST_REMOTE).to.equal("RoleRequest")
			expect(Data.ROLE_REQUEST_REMOTE).never.to.equal(Data.PAD_REQUEST_REMOTE)
		end)

		it("is ABSENT for a man who owns nothing, which is what hides both controls", function()
			-- NOT GREYED, NOT LOCKED -- absent. *"A control for a thing you do not have is an
			-- advertisement, and this shop already has a shop for that."* It is also the switch-off
			-- story: with the shop off nobody owns the row, so this branch is every build today.
			expect(Lobby.wishFor(nil, false, nil)).to.equal(nil)
			expect(Lobby.wishFor(Data.ROLE_WISH.BEATER, false, nil)).to.equal(nil)
			expect(Lobby.wishFor(Data.ROLE_WISH.BEATER, false, "Drivers")).to.equal(nil)
		end)

		it("defaults to HUNTER for an owner who has not touched it", function()
			expect(Lobby.wishFor(nil, true, nil)).to.equal(Data.ROLE_WISH.HUNTER)
			-- ...AND A STORED VALUE THIS SYSTEM DOES NOT KNOW IS HUNTER TOO, never a third state.
			expect(Lobby.wishFor("nonsense", true, nil)).to.equal(Data.ROLE_WISH.HUNTER)
		end)

		it("stands while no drive has given him a side", function()
			expect(Lobby.wishFor(Data.ROLE_WISH.BEATER, true, nil)).to.equal(Data.ROLE_WISH.BEATER)
		end)

		it("is SPENT by an assignment and by nothing else", function()
			-- THE SINGLE MOST IMPORTANT RULE IN THE DESIGN: *"a man who beat once and forgot would
			-- quietly stop being a hunter for ever, which is the opposite of the thing he paid 2000
			-- for"*. The control says NEXT DRIVE and means exactly one.
			--
			-- AND IT IS KEYED ON THE TEAM, NOT ON "IS HE IN A DRIVE": `Lobby.depart` -> `Match.enrol`
			-- makes him a participant immediately, while the assignment that READS the wish happens
			-- on a later `Match` step -- so a reset keyed on the earlier fact would clear the wish
			-- before the assignment it was meant to change.
			for _, side in ipairs({ "Drivers", "Shooters" }) do
				expect(Lobby.wishFor(Data.ROLE_WISH.BEATER, true, side)).to.equal(Data.ROLE_WISH.HUNTER)
			end
		end)

		it("can only ever CLEAR, so a spent wish cannot come back", function()
			-- THE RECONCILIATION NEVER INVENTS ONE: feed its own answer back in and the only fixed
			-- points are nil (he owns nothing) and HUNTER (the default). BEATER is reachable only
			-- from a stored ask, which only the door writes.
			local once = Lobby.wishFor(Data.ROLE_WISH.BEATER, true, "Drivers")
			expect(once).to.equal(Data.ROLE_WISH.HUNTER)
			expect(Lobby.wishFor(once, true, nil)).to.equal(Data.ROLE_WISH.HUNTER)
			expect(Lobby.wishFor(once, true, "Shooters")).to.equal(Data.ROLE_WISH.HUNTER)
		end)

		it("has its own words and its own pixels, and the block adds up to BLOCK_PX", function()
			local ROLE = CFG.PADS.PANEL.ROLE
			-- EVERY WORD IS A ROW, because words are Karen's to rewrite, and no two of the THREE
			-- captions are the same sentence. There were four until task 242: `NOTE_NONE`, the
			-- party-of-one refusal, went when the solo wisher started being honoured
			-- (`backups/2026-10-22_task-242_no-beaters-this-drive.md`), and it is asserted ABSENT
			-- below so a reader cannot bring the sentence back without reading why it left.
			for _, key in ipairs({
				"EYEBROW",
				"HUNTER",
				"BEATER",
				"NOTE_HUNTER",
				"NOTE_BEATER",
				"NOTE_SENT",
			}) do
				expect(type(ROLE[key])).to.equal("string")
				expect(#ROLE[key] > 0).to.equal(true)
			end
			expect(ROLE.NOTE_NONE).to.equal(nil)
			local seen: { [string]: boolean } = {}
			for _, key in ipairs({ "NOTE_HUNTER", "NOTE_BEATER", "NOTE_SENT" }) do
				expect(seen[ROLE[key]]).to.equal(nil)
				seen[ROLE[key]] = true
			end
			-- THE NINE ROWS SUM TO THE ONE NUMBER BOTH THE LAYOUT AND THE CLIENT SPEC READ, so a part
			-- that changes without the whole fails here rather than drawing 1 px wrong in silence.
			local sum = ROLE.LEAD_PX
				+ ROLE.EYEBROW_PX
				+ ROLE.GAP_PX
				+ ROLE.TRACK_PX
				+ ROLE.NOTE_GAP
				+ ROLE.NOTE_PX
				+ ROLE.RULE_GAP
				+ ROLE.RULE_PX
				+ ROLE.TRAIL_PX
			expect(sum).to.equal(ROLE.BLOCK_PX)
			expect(ROLE.BLOCK_PX).to.equal(119)
		end)
	end)

	-- -------------------------------------- THE LOBBY CLEARS ITS OWN GROUND (task 249)
	--
	-- KAREN, 2026-10-23, with a frame of a bush standing between her and TRUCK 4's pad: *"remove
	-- this bush"*. It is not one of OUR trees -- measured in her place, every `TreeLine` and
	-- `LODGE_TREES` trunk is 40 studs or more from the nearest pad -- it is
	-- `Workspace.Session.Bush`, a piece of the BOUGHT forest the Forest Test place was built from,
	-- standing at **(2871, -2965)**.
	describe("the working ground is kept clear (task 249)", function()
		local anchorXZ = Data.anchorFor("forest-test") :: any
		local anchor = Vector3.new(anchorXZ.x, 150, anchorXZ.z)

		it("says yes to the bush Karen photographed and no to the wood around it", function()
			-- HER BUSH, BY ITS MEASURED COORDINATES. 12.0 studs west of `Build.yardRect`'s own
			-- edge, which is why `CLEARING.YARD_MARGIN_STUDS` is 12.
			expect(Build.onWorkingGround(2871, -2965, anchor, CFG)).to.equal(true)
			-- THE GRAVEL ITSELF, and the four bays on it.
			local yardX, _, yardZ = Build.yardRect(anchor, CFG)
			expect(Build.onWorkingGround(yardX, yardZ, anchor, CFG)).to.equal(true)
			-- ...AND THE WOOD. The ring of trees this lobby plants itself stands 40+ studs from the
			-- nearest pad and must be left exactly where it is, so a point out there is NOT on the
			-- working ground.
			expect(Build.onWorkingGround(anchor.X - 200, anchor.Z - 200, anchor, CFG)).to.equal(false)
			expect(Build.onWorkingGround(anchor.X + 200, anchor.Z + 200, anchor, CFG)).to.equal(false)
			-- BEHIND THE HOUSE IS NOT THE FRONT OF IT. Karen's words are *"the yard and the lodge
			-- front"*, and the alder grove in the hollow behind the lodge is ours and stays.
			local lodge = anchor + CFG.LODGE.OFFSET
			expect(Build.onWorkingGround(lodge.X, lodge.Z + CFG.LODGE.SIZE.Z, anchor, CFG)).to.equal(false)
			-- ...AND THE FRONT IS. One `FRONT_STUDS` out from the south face, on the centre line.
			expect(
				Build.onWorkingGround(
					lodge.X,
					lodge.Z - CFG.LODGE.SIZE.Z / 2 - CFG.CLEARING.FRONT_STUDS / 2,
					anchor,
					CFG
				)
			).to.equal(true)
			-- ...AND THE GATHERING YARD IS WORKING GROUND TOO (task 261, item 4). It moved to x -62
			-- and grew to 80 x 80 for thirty animals, and the `Yard` rectangle plus its 12-stud
			-- margin reaches only x -54 -- so 48 studs of the gathering's own ground used to be
			-- outside every sweep, and a world bush standing among the animals Karen asked to SEE is
			-- the same mistake `treeLine`'s third exclusion already refuses for our own trees.
			local gather = Data.gatherPad(CFG) :: any
			local gatherAt = anchor + gather.OFFSET
			expect(Build.onWorkingGround(gatherAt.X, gatherAt.Z, anchor, CFG)).to.equal(true)
			-- ITS WEST EDGE, which is the part the `Yard` rectangle never reached...
			expect(Build.onWorkingGround(gatherAt.X - gather.SIZE.X / 2 + 1, gatherAt.Z, anchor, CFG)).to.equal(true)
			-- ...AND ONE STUD BEYOND IT IS THE WOOD AGAIN, so the sweep is bounded by the row and not
			-- by a guess.
			expect(Build.onWorkingGround(gatherAt.X - gather.SIZE.X / 2 - 1, gatherAt.Z - gather.SIZE.Z, anchor, CFG)).to.equal(
				false
			)
		end)

		it("takes the world's foliage off it, and counts what it took", function()
			-- A WORLD OF THIS SPEC'S OWN, which is what keeps this case out of the DEV place's
			-- Workspace entirely: one folder with one of the names `CLEARING.FOLDERS` holds, one
			-- part standing where Karen's bush stands and one standing out in the wood.
			local world = Instance.new("Folder")
			local session = Instance.new("Folder")
			session.Name = CFG.CLEARING.FOLDERS[1]
			session.Parent = world
			local bush = Instance.new("Part")
			bush.Name = "Bush"
			bush.Anchored = true
			bush.Position = Vector3.new(2871, 149, -2965)
			bush.Parent = session
			local far = Instance.new("Part")
			far.Name = "Tree3"
			far.Anchored = true
			far.Position = Vector3.new(anchor.X - 200, 149, anchor.Z - 200)
			far.Parent = session
			-- ...AND A FOLDER THAT IS NOT THE WORLD'S FOLIAGE, standing on the gravel. Nothing in
			-- it may be touched, whatever it is or where it stands: the sweep is bounded by name.
			local ours = Instance.new("Folder")
			ours.Name = "Lobby"
			ours.Parent = world
			local pad = Instance.new("Part")
			pad.Name = "TruckPad1"
			pad.Anchored = true
			pad.Position = Vector3.new(2871, 150, -2965)
			pad.Parent = ours

			expect(Build.clearWorkingGround(world, anchor, CFG)).to.equal(1)
			expect(bush.Parent).to.equal(nil)
			expect(far.Parent).to.equal(session)
			expect(pad.Parent).to.equal(ours)
			-- IDEMPOTENT: a second sweep over the same world takes nothing, so a rebuild cannot
			-- keep eating the forest a model at a time.
			expect(Build.clearWorkingGround(world, anchor, CFG)).to.equal(0)
			-- ...AND NO WORLD AT ALL IS 0 AND NOT A THROW, which is every spec that drives
			-- `Build.build` with a container of its own.
			expect(Build.clearWorkingGround(nil, anchor, CFG)).to.equal(0)
			world:Destroy()
		end)
	end)

	-- ---------------------------------------------------------------- task 311
	--
	-- KAREN, 2026-10-28: *"also you can add in middle somewhere flag long stick and flag like in
	-- hunting lobbies ... forest road comming to lobby around trees on the side or road bjorke tree
	-- from both sides with spaces / nice and clean"*.
	--
	-- EVERY CLEARANCE HERE IS AGAINST A MEASURED BOX, not against a guess: the numbers in the
	-- comments come out of `<runs-dir>/evidence/p311-geom.txt`, taken in her place in Play.
	-- Note: docs/research/2026-10-29-lobby-flagpole-and-birch-avenue.md
	describe("the flagpole and the birch avenue (task 311)", function()
		local anchor = Vector3.new(2850, 149.25, -2950)

		it("is a ten-metre pole carrying the flag the sources pair with it", function()
			local spec = CFG.FLAGPOLE
			-- 10 m at 0.28 m per stud is 35.71; the Swedish guides pair a 9-10 m pole with a
			-- 240 x 150 cm flag, which is 8.57 x 5.36 studs.
			expect(math.abs(spec.HEIGHT_STUDS - 10 / 0.28) < 0.5).to.equal(true)
			expect(math.abs(spec.FLAG.X - 2.4 / 0.28) < 0.1).to.equal(true)
			expect(math.abs(spec.FLAG.Y - 1.5 / 0.28) < 0.1).to.equal(true)
			-- THE FLAG IS HOISTED NEAR THE TOP and not halfway up the mast.
			expect(spec.FLAG_TOP_BELOW_FINIAL_STUDS <= 1.5).to.equal(true)
			expect(spec.FLAG_TOP_BELOW_FINIAL_STUDS > 0).to.equal(true)
			-- A REAL 10 m POLE IS 75-110 mm AT THE FOOT. Thinner than 0.3 studs stops reading as a
			-- pole from the road, which is why this is at the top of that range and not the middle.
			expect(spec.DIAMETER_STUDS * 0.28 * 1000 <= 115).to.equal(true)
			expect(spec.DIAMETER_STUDS >= 0.3).to.equal(true)
			-- AND THE CLEAT IS WHERE A HAND REACHES IT, 1.2 m up.
			expect(spec.CLEAT_Y_STUDS < spec.HEIGHT_STUDS / 4).to.equal(true)
		end)

		it("stands on the yard's gravel, clear of the pads, the bays, the lodge and the spawn", function()
			local foot = Build.flagpoleFoot(anchor, CFG, nil)
			local radius = CFG.FLAGPOLE.BASE_STUDS / 2
			-- ON THE GRAVEL: inside `Build.yardRect`, so the pole has gravel under it rather than
			-- grass -- and inside the blade-free pad, which is what `onWorkingGround` answers.
			local midX, halfX, midZ, halfZ = Build.yardRect(anchor, CFG)
			expect(math.abs(foot.X - midX) + radius <= halfX).to.equal(true)
			expect(math.abs(foot.Z - midZ) + radius <= halfZ).to.equal(true)
			expect(Build.onWorkingGround(foot.X, foot.Z, anchor, CFG)).to.equal(true)
			-- OFF THE ROAD SURFACE: a flagpole in the lane would be the mirror of task 209's fence
			-- post inside the cabin.
			expect(Build.offRoad(foot.X, anchor, CFG)).to.equal(true)
			-- CLEAR OF ALL FOUR PADS. 9 x 12 each (`PADS.SIZE`), centred by `Pads.centreFor`.
			for index = 1, CFG.TRUCK.COUNT do
				local pad = Pads.centreFor(anchor, index, CFG)
				local dx = math.max(0, math.abs(foot.X - pad.X) - CFG.PADS.SIZE.X / 2 - radius)
				local dz = math.max(0, math.abs(foot.Z - pad.Z) - CFG.PADS.SIZE.Z / 2 - radius)
				expect(math.max(dx, dz) > 0).to.equal(true)
			end
			-- CLEAR OF THE LODGE AND ITS PORCH, whose keep-out box this module already owns. Through
			-- `Build.insideLodgeBox`, because `lodgeKeepOut` returns a CENTRE and HALF-EXTENTS and
			-- reading it as a min and a max answers "outside" for almost any point.
			expect(Build.insideLodgeBox(Vector2.new(foot.X, foot.Z), anchor, CFG)).to.equal(false)
			-- ...and the box really does bite: the lodge's own centre is inside it.
			local door = anchor + CFG.LODGE.OFFSET
			expect(Build.insideLodgeBox(Vector2.new(door.X, door.Z), anchor, CFG)).to.equal(true)
			-- ...AND OFF THE SPAWN PAD, which is where a man materialises.
			local spawn = anchor + CFG.SPAWN.OFFSET
			expect(math.abs(foot.Z - spawn.Z) > CFG.SPAWN.SIZE.Z / 2 + radius).to.equal(true)
		end)

		-- REPLACED IN TASK 315. It asserted every avenue slot was >150 studs from the range anchor;
		-- the range now stands straight out of the shop door and the southernmost slot is 70.0 studs
		-- from it, so the old case fails BY ARITHMETIC. Its replacement is the rule that took its
		-- place: the pole survives the corridor and no avenue trunk is planted at all.
		it("keeps the flagpole out of the range's corridor, and plants no avenue trunk inside it", function()
			local RangeData = require(ReplicatedStorage:WaitForChild("Range"))
			local range = RangeData.anchorFor("forest-test") :: any
			expect(range).to.be.ok()
			local at = Vector3.new(range.x, 0, range.z)
			local dir = RangeData.downrangeOf(range)
			local lane = RangeData.sightlineFrom(at, RangeData.LAYOUT, dir)
			local keep = { RangeData.footprintFor(at, RangeData.LAYOUT, dir) }
			-- THE POLE SURVIVES, and by how much is the point of the assertion: its foot is 2 studs
			-- north of the corridor's own north edge, so a later change to `LODGE.SIZE.Z` or to
			-- `FLAGPOLE.OFFSET` cannot quietly swallow it (design 5.2).
			local foot = Build.flagpoleFoot(anchor, CFG, nil)
			expect(Build.keptClear(foot.X, foot.Z, anchor, CFG, keep, lane)).to.equal(false)
			local rect = Build.sightlineRect(lane, anchor, CFG) :: any
			TestKit.note(
				string.format(
					"task 315: corridor x %.1f..%.1f z %.1f..%.1f; flagpole foot (%.0f, %.0f) is %.1f studs north of it",
					rect.minX,
					rect.maxX,
					rect.minZ,
					rect.maxZ,
					foot.X,
					foot.Z,
					foot.Z - rect.maxZ
				)
			)
			-- ...AND NOT ONE AVENUE TREE IS PLANTED, read off the planner rather than off the table:
			-- `SHIFT_STUDS` walks a fouled slot NORTH, further INTO the corridor, so the decision
			-- has to be read where the slot ENDS UP.
			local planted, dropped = 0, 0
			for _, planRow in ipairs(Build.avenuePlan(anchor, CFG, {}, keep, lane)) do
				if planRow.dropped then
					dropped += 1
				else
					planted += 1
				end
			end
			expect(planted).to.equal(0)
			expect(dropped > 0).to.equal(true)
			TestKit.note(string.format("task 315: avenue slots dropped by the corridor: %d", dropped))
			-- THE BITE: with no range handed in, the avenue is exactly what it was. A rule that
			-- answered the same either way would pass the lines above for free.
			local before = 0
			for _, planRow in ipairs(Build.avenuePlan(anchor, CFG, {}, nil, nil)) do
				if not planRow.dropped then
					before += 1
				end
			end
			expect(before >= 5).to.equal(true)
		end)

		-- THE PREDICATE ITSELF, WITH NOTHING BUILT (task 315, design 15.1 case 10). Every coordinate
		-- below was MEASURED in Karen's place at main d4b10eda and is listed in
		-- `reviews/task-315/BRIEF.md` section 2 -- so this case is about her trees, not about a
		-- rectangle agreeing with itself.
		it("keptClear bites on every measured trunk and on nothing a player uses", function()
			local RangeData = require(ReplicatedStorage:WaitForChild("Range"))
			local range = RangeData.anchorFor("forest-test") :: any
			local at = Vector3.new(range.x, 0, range.z)
			local dir = RangeData.downrangeOf(range)
			local lane = RangeData.sightlineFrom(at, RangeData.LAYOUT, dir)
			local keep = { RangeData.footprintFor(at, RangeData.LAYOUT, dir) }
			local inside = {
				{ "Avenue05", 2846.9, -2948.0 },
				{ "Avenue03", 2846.7, -2997.3 },
				{ "Avenue08", 2893.8, -2997.1 },
				{ "Avenue07", 2894.8, -3015.3 },
				{ "Avenue02", 2846.4, -3023.7 },
				{ "Tree12", 2901.7, -3028.0 },
				{ "Tree18", 2812.3, -3032.0 },
				{ "Tree19", 2792.8, -3033.3 },
				{ "Tree17", 2827.0, -3040.4 },
				{ "Tree13", 2892.1, -3044.8 },
				{ "Session.Tree8 (the pine)", 2844.0, -3188.0 },
			}
			for _, trunk in ipairs(inside) do
				expect(Build.keptClear(trunk[2] :: number, trunk[3] :: number, anchor, CFG, keep, lane)).to.equal(
					true,
					string.format("%s should be cleared", trunk[1] :: string)
				)
				-- ...AND WITH NO RANGE HANDED IN, NONE OF THEM IS: the no-range world, bit for bit.
				expect(Build.keptClear(trunk[2] :: number, trunk[3] :: number, anchor, CFG, nil, nil)).to.equal(
					false,
					string.format("%s must survive in a world with no range", trunk[1] :: string)
				)
			end
			local outside = {
				{ "Tree22, west of the corridor", 2765.4, -2993.2 },
				{ "Tree20", 2779.0, -3025.7 },
				{ "lodge centre, north of the corridor", 2850.0, -2904.0 },
				{ "a trunk 50 studs out in the wood", 2948.8, -2964.4 },
			}
			for _, spot in ipairs(outside) do
				expect(Build.keptClear(spot[2] :: number, spot[3] :: number, anchor, CFG, keep, lane)).to.equal(
					false,
					string.format("%s must not be cleared", spot[1] :: string)
				)
			end
			-- TWO THINGS ARE INSIDE THE CORRIDOR THAT ARE NOT TREES, AND THEY ARE STATED RATHER
			-- THAN HIDDEN (design 5.2), because a reader who found them later would be right to ask:
			--   * THE SPAWN PAD (2850, -2934). The rule reaches the lodge's own south face, so the
			--     porch strip and the spawn are in it.
			--   * THE GATHERING YARD'S EASTERN EDGE. Its centre is 4.5 studs inside the corridor's
			--     west edge -- MEASURED here off both configs rather than typed.
			-- Both are harmless because the rule removes only TREES, and both rectangles are already
			-- kept clear of trees by `treeLine`'s own exclusions and by `onWorkingGround`.
			expect(Build.keptClear(2850.0, -2934.0, anchor, CFG, keep, lane)).to.equal(true)
			local gatherPad = Data.gatherPad(CFG)
			expect(gatherPad).to.be.ok()
			local gatherAt = anchor + (gatherPad :: any).OFFSET
			expect(Build.keptClear(gatherAt.X, gatherAt.Z, anchor, CFG, keep, lane)).to.equal(true)
			TestKit.note(
				string.format(
					"task 315: the corridor's west edge %.1f cuts %.1f studs into the gathering yard (centre x %.1f); it removes only trees, and treeLine already excludes that rectangle",
					(Build.sightlineRect(lane, anchor, CFG) :: any).minX,
					gatherAt.X + (gatherPad :: any).SIZE.X / 2 - (Build.sightlineRect(lane, anchor, CFG) :: any).minX,
					gatherAt.X
				)
			)
			-- EVERY LODGE_TREES TRUNK SURVIVES, in the lodge's own frame: zero of the twelve are in
			-- the corridor today, which is what the guard in `lodgeTrees` is there to keep true.
			local origin = anchor + CFG.LODGE.OFFSET
			for _, treeRow in ipairs(CFG.LODGE_TREES) do
				expect(Build.keptClear(origin.X + treeRow.x, origin.Z + treeRow.z, anchor, CFG, keep, lane)).to.equal(
					false
				)
			end
		end)

		-- THE LIVE BUILD, AND THE TWO COUNTERS THE TREE CLAIM RESTS ON (round 1, finding 3; design
		-- 15.1 item 11, W5). Until this case `sightlineDropped` and `sightlineCleared` had no spec
		-- at all: deleting every `+= 1` left the suite green and the boot line simply printed 0 --
		-- which is the same class of defect as the counters living only in `Build`'s table, caught
		-- live in her place in round 1.
		it("plants nothing in the corridor, and BOTH counters carry the number through Lobby.stats", function()
			local RangeData = require(ReplicatedStorage:WaitForChild("Range"))
			local range = RangeData.anchorFor("forest-test") :: any
			local at = Vector3.new(range.x, 0, range.z)
			local dir = RangeData.downrangeOf(range)
			local lane = RangeData.sightlineFrom(at, RangeData.LAYOUT, dir)
			local keep = { RangeData.footprintFor(at, RangeData.LAYOUT, dir) }
			local rect = Build.sightlineRect(lane, anchor, CFG) :: any

			local container = Instance.new("Folder")
			container.Name = "LobbySpec315Corridor"
			container.Parent = Workspace
			-- THE WORLD'S OWN FOLIAGE, as a fixture this case plants itself: one trunk standing where
			-- the pine stood, so `sightlineCleared` has something real to count.
			local session = Instance.new("Folder")
			session.Name = "Session"
			session.Parent = container
			local pine = Instance.new("Part")
			pine.Name = "ThePine"
			pine.Anchored = true
			pine.Size = Vector3.new(2, 2, 2)
			pine.Position = Vector3.new(2844, 0, -3188)
			pine.Parent = session

			local templates = fakeTemplates()
			local folder = Build.build(
				container,
				anchor,
				CFG,
				templates,
				{
					keepClear = keep,
					sightline = lane,
				} :: any
			)

			-- NOT ONE TRUNK STANDS IN EITHER RECTANGLE, read off what was really planted.
			local standing, inside = 0, {}
			for _, grove in ipairs({ "TreeLine", "LodgeTrees", "Avenue" }) do
				local f = folder:FindFirstChild(grove)
				if f ~= nil then
					for _, tree in ipairs((f :: Instance):GetChildren()) do
						local q = if tree:IsA("BasePart")
							then (tree :: BasePart).Position
							else (tree :: Model):GetPivot().Position
						standing += 1
						if Build.keptClear(q.X, q.Z, anchor, CFG, keep, lane) then
							table.insert(inside, string.format("%s at %.0f,%.0f", tree.Name, q.X, q.Z))
						end
					end
				end
			end
			expect(#inside).to.equal(0, "planted in the corridor: " .. table.concat(inside, ", "))
			expect(standing > 0).to.equal(true)

			-- THE TWO COUNTERS, AND THEY ARE NOT ZERO. `sightlineDropped` is ours; `sightlineCleared`
			-- is the world's own trunk the sweep took.
			local built = Build.stats()
			expect(built.sightlineDropped > 0).to.equal(
				true,
				string.format("sightlineDropped is %d -- nothing was counted", built.sightlineDropped)
			)
			expect(built.sightlineCleared).to.equal(1)
			expect(pine.Parent).to.equal(nil)
			-- ...AND THE AVENUE IS WHOLLY DROPPED, which is the number the backup note records.
			local avenue = folder:FindFirstChild("Avenue")
			expect(if avenue == nil then 0 else #(avenue :: Instance):GetChildren()).to.equal(0)
			TestKit.note(
				string.format(
					"task 315: live build planted %d trees, 0 in the corridor; sightlineDropped=%d sightlineCleared=%d; corridor x %.1f..%.1f z %.1f..%.1f",
					standing,
					built.sightlineDropped,
					built.sightlineCleared,
					rect.minX,
					rect.maxX,
					rect.minZ,
					rect.maxZ
				)
			)
			local droppedWith = built.sightlineDropped

			-- THE BITE: the SAME build with no rectangles handed in plants the avenue and counts
			-- nothing, so neither the rule nor the counters can pass for free.
			local plainContainer = Instance.new("Folder")
			plainContainer.Name = "LobbySpec315NoRange"
			plainContainer.Parent = Workspace
			local plainTemplates = fakeTemplates()
			local plainFolder = Build.build(plainContainer, anchor, CFG, plainTemplates)
			local plainStats = Build.stats()
			expect(plainStats.sightlineDropped).to.equal(0)
			expect(plainStats.sightlineCleared).to.equal(0)
			local plainAvenue = plainFolder:FindFirstChild("Avenue")
			expect(if plainAvenue == nil then 0 else #(plainAvenue :: Instance):GetChildren() > 0).to.equal(true)
			TestKit.note(
				string.format(
					"task 315: with no range handed in, %d dropped (was %d)",
					plainStats.sightlineDropped,
					droppedWith
				)
			)

			container:Destroy()
			templates:Destroy()
			plainContainer:Destroy()
			plainTemplates:Destroy()
		end)

		-- W7, AT ONE-STUD STEPS AND ACROSS THE SEAM (round 1, finding 3; design 15.1 item 13). The
		-- case above this one samples three points from the lodge ANCHOR; the walk Karen takes
		-- starts at the DOOR, and the one place it could break is the 3 studs where the field and
		-- the footprint overlap (z -3060..-3057). Every stud of it is asked here.
		it("leaves a man home at every single stud of the walk from the shop door to every mat", function()
			local RangeData = require(ReplicatedStorage:WaitForChild("Range"))
			local range = RangeData.anchorFor("forest-test") :: any
			local rangeAt = Vector3.new(range.x, 0, range.z)
			local footprint = RangeData.footprintFor(rangeAt, RangeData.LAYOUT, RangeData.downrangeOf(range))
			local areas = Join.homeAreas(anchor, CFG, { footprint })
			-- THE DOOR IS THE LODGE'S SOUTH FACE on its own centre line, off the lobby's config.
			local door =
				Vector3.new(anchor.X + CFG.LODGE.OFFSET.X, 0, anchor.Z + CFG.LODGE.OFFSET.Z - CFG.LODGE.SIZE.Z / 2)
			local worst, steps, seam = nil, 0, 0
			for spot = 1, RangeData.LAYOUT.SPOT_COUNT do
				local mat = RangeData.matPosition(rangeAt, spot, RangeData.LAYOUT)
				local span = Vector3.new(mat.X - door.X, 0, mat.Z - door.Z)
				local length = math.floor(span.Magnitude)
				for step = 0, length do
					local at = door + span.Unit * step
					steps += 1
					if at.Z <= -3060 and at.Z >= -3057 then
						seam += 1
					end
					if worst == nil and not Join.insideHome(at, areas) then
						worst = at
					end
				end
			end
			expect(worst).to.equal(
				nil,
				if worst == nil
					then ""
					else string.format("off home at %.1f, %.1f", (worst :: Vector3).X, (worst :: Vector3).Z)
			)
			expect(steps > 1000).to.equal(true)
			-- THE BITE: with no footprint handed in, the old field rule leaves most of that walk out.
			local fieldOnly = Join.homeAreas(anchor, CFG, nil)
			local offField = 0
			for spot = 1, RangeData.LAYOUT.SPOT_COUNT do
				local mat = RangeData.matPosition(rangeAt, spot, RangeData.LAYOUT)
				local span = Vector3.new(mat.X - door.X, 0, mat.Z - door.Z)
				for step = 0, math.floor(span.Magnitude) do
					if not Join.insideHome(door + span.Unit * step, fieldOnly) then
						offField += 1
					end
				end
			end
			expect(offField > 100).to.equal(true)
			TestKit.note(
				string.format(
					"task 315: %d one-stud samples on the six door-to-mat walks, all home; %d of them are in the field/footprint seam; %d would be sent back by the field alone",
					steps,
					seam,
					offField
				)
			)
		end)

		-- THE SWEEP TAKES THE WORLD'S OWN FOLIAGE OUT OF BOTH RECTANGLES, and only out of them.
		it("sweeps a fixture in the range's footprint and in its corridor, and spares one beside each", function()
			local RangeData = require(ReplicatedStorage:WaitForChild("Range"))
			local range = RangeData.anchorFor("forest-test") :: any
			local at = Vector3.new(range.x, 0, range.z)
			local dir = RangeData.downrangeOf(range)
			local lane = RangeData.sightlineFrom(at, RangeData.LAYOUT, dir)
			local keep = { RangeData.footprintFor(at, RangeData.LAYOUT, dir) }
			local rect = Build.sightlineRect(lane, anchor, CFG) :: any
			local world = Instance.new("Folder")
			local session = Instance.new("Folder")
			session.Name = "Session"
			session.Parent = world
			local function fixture(name: string, x: number, z: number): BasePart
				local part = Instance.new("Part")
				part.Name = name
				part.Anchored = true
				part.Size = Vector3.new(2, 2, 2)
				part.Position = Vector3.new(x, 0, z)
				part.Parent = session
				return part
			end
			local pine = fixture("ThePine", 2844, -3188)
			local inCorridor = fixture("InCorridor", (rect.minX + rect.maxX) / 2, rect.minZ + 5)
			local beside = fixture("BesideCorridor", rect.minX - 2, rect.minZ + 5)
			local farAway = fixture("FarAway", 2500, -3500)
			local removed = Build.clearWorkingGround(world, anchor, CFG, keep, lane)
			expect(removed).to.equal(2)
			expect(pine.Parent).to.equal(nil)
			expect(inCorridor.Parent).to.equal(nil)
			expect(beside.Parent).to.equal(session)
			expect(farAway.Parent).to.equal(session)
			world:Destroy()
			-- THE BITE: with no rectangles handed in, the same fixture survives.
			local world2 = Instance.new("Folder")
			local session2 = Instance.new("Folder")
			session2.Name = "Session"
			session2.Parent = world2
			local part2 = Instance.new("Part")
			part2.Name = "ThePine"
			part2.Anchored = true
			part2.Size = Vector3.new(2, 2, 2)
			part2.Position = Vector3.new(2844, 0, -3188)
			part2.Parent = session2
			expect(Build.clearWorkingGround(world2, anchor, CFG, nil, nil)).to.equal(0)
			expect(part2.Parent).to.equal(session2)
			world2:Destroy()
		end)

		it("is an avenue: two rows, at least five trees, a gap, and 7 m in the row", function()
			local spec = CFG.AVENUE
			local west, east, gaps = 0, 0, 0
			local byRow: { [number]: { number } } = { [-1] = {}, [1] = {} }
			for _, slot in ipairs(spec.SLOTS) do
				expect(slot.side == -1 or slot.side == 1).to.equal(true)
				if slot.gap then
					gaps += 1
				elseif slot.side < 0 then
					west += 1
				else
					east += 1
				end
				table.insert(byRow[slot.side], slot.z)
			end
			-- NATURVARDSVERKET'S OWN DEFINITION: deciduous trees in one or two rows along a road,
			-- at least five of them. It sets no spacing at all, which is why the spacing below is
			-- argued from a road authority instead.
			expect(west + east >= 5).to.equal(true)
			expect(west > 0 and east > 0).to.equal(true)
			-- "FROM BOTH SIDES WITH SPACES": at least one slot is a dead individual's gap, which the
			-- Haninge bjorkalle survey records as normal.
			expect(gaps >= 1).to.equal(true)
			-- 7 m (25 studs) IN THE ROW, inside the 12 m per deciduous tree a road authority gives
			-- and tighter because this birch carries a ~10-stud crown at these scales.
			for _, zs in pairs(byRow) do
				table.sort(zs)
				for index = 2, #zs do
					local step = zs[index] - zs[index - 1]
					expect(step >= 20).to.equal(true)
					expect(step * 0.28 <= 12).to.equal(true)
				end
			end
			-- IT IS A BIRCH, and the model comes from the one allow-list there is.
			local found = false
			for _, row in ipairs(CFG.TREELINE.SPECIES) do
				if row.KIND == spec.KIND then
					found = true
				end
			end
			expect(found).to.equal(true)
			expect(spec.KIND).to.equal("birch")
		end)

		it("stands every avenue trunk off the road and stops before the yard", function()
			local spec = CFG.AVENUE
			local midX, halfX, midZ, halfZ = Build.yardRect(anchor, CFG)
			for index, slot in ipairs(spec.SLOTS) do
				local at = Build.avenueAt(anchor, slot, CFG)
				-- OFF THE LANE AND BOTH VERGES, by `KEEP_OFF_STUDS`. A trunk in the road is the one
				-- thing an avenue may never be.
				expect(Build.offRoad(at.X, anchor, CFG)).to.equal(true)
				-- AND OUT OF THE GRAVEL YARD: "stop the avenue before the yard", which for the east
				-- row means stopping south of it and for the west row means passing west of it.
				local insideYard = math.abs(at.X - midX) <= halfX and math.abs(at.Y - midZ) <= halfZ
				if insideYard then
					expect(string.format("avenue slot %d is inside the yard", index)).to.equal(false)
				end
				-- NOR IN THE LODGE OR ITS PORCH.
				expect(Build.insideLodgeBox(at, anchor, CFG)).to.equal(false)
			end
			-- THE OFFSET ITSELF CLEARS THE FENCE LINE, so a birch never grows through a rail.
			expect(spec.OFF_ROAD_STUDS > CFG.FENCE.OFF_ROAD_STUDS).to.equal(true)
		end)

		it("refuses a point in the road, and says so for the lane's own centre", function()
			-- A NEGATIVE CONTROL (review round 1, note): every other assertion on `offRoad` expects
			-- true, so a body of `return true` passed the whole file -- and `offRoad` is the road
			-- guard inside the avenue's own keep-out.
			local centre = anchor.X + CFG.ROAD.CENTRE_X
			expect(Build.offRoad(centre, anchor, CFG)).to.equal(false)
			local verge = centre + CFG.ROAD.WIDTH_STUDS / 2 + CFG.ROAD.VERGE_STUDS
			expect(Build.offRoad(verge, anchor, CFG)).to.equal(false)
			expect(Build.offRoad(verge + CFG.AVENUE.KEEP_OFF_STUDS, anchor, CFG)).to.equal(true)
			-- ...AND THE SAME FOR THE WHOLE KEEP-OUT: the yard, a pad, a bay and the house are all
			-- refused, which is what review round 1's finding 3 found nothing enforcing.
			local midX, _halfX, midZ, _halfZ = Build.yardRect(anchor, CFG)
			expect(Build.plantable(Vector2.new(midX, midZ), anchor, CFG)).to.equal(false)
			local deck = Pads.centreFor(anchor, 4, CFG)
			expect(Build.plantable(Vector2.new(deck.X, deck.Z), anchor, CFG)).to.equal(false)
			local door = anchor + CFG.LODGE.OFFSET
			expect(Build.plantable(Vector2.new(door.X, door.Z), anchor, CFG)).to.equal(false)
			-- ...AND A REAL AVENUE SLOT IS PLANTABLE, so the rule is not simply "false": the first
			-- non-gap row of the shipped table, which is where a birch is meant to stand.
			local live = Build.avenueAt(anchor, CFG.AVENUE.SLOTS[1], CFG)
			expect(Build.plantable(live, anchor, CFG)).to.equal(true)
		end)

		it("walks a fouled slot north, drops one it cannot clear, and never onto the yard", function()
			-- REVIEW ROUND 1, FINDING 2: the old case passed with the whole shift-and-drop loop
			-- deleted, because `avenueTrees + avenueDropped == slots - gaps` is a bookkeeping
			-- identity over two counters in the same branchless pair. `Build.avenuePlan` is pure, so
			-- this hands it a trunk standing ON a slot and asserts the tree MOVED -- which is false
			-- the moment the loop goes.
			local spec = CFG.AVENUE
			local clear = Build.avenuePlan(anchor, CFG, {})
			expect(#clear > 0).to.equal(true)
			local first = clear[1]
			expect(first.dropped).never.to.equal(true)
			expect(first.shifted).to.equal(0)

			-- ONE TRUNK JUST SOUTH OF THAT SLOT: 7 studs away, inside `KEEP_OFF_TREES_STUDS` (14),
			-- and one 8-stud step north puts the tree 15 away -- so it must move EXACTLY once. A
			-- trunk ON the slot would need two steps, which is the same proof with a worse number.
			local near = Vector2.new(first.at.X, first.at.Y - 7)
			local fouledPlan = Build.avenuePlan(anchor, CFG, { near })
			local moved = nil
			for _, row in ipairs(fouledPlan) do
				if row.index == first.index then
					moved = row
				end
			end
			expect(moved).to.be.ok()
			expect((moved :: any).dropped).never.to.equal(true)
			expect((moved :: any).shifted).to.equal(1)
			expect((moved :: any).at.Y - first.at.Y).to.equal(spec.SHIFT_STUDS)
			expect((moved :: any).at.X).to.equal(first.at.X)

			-- A WALL OF TRUNKS UP THE WHOLE SHIFT RANGE: no step can clear it, so it is DROPPED and
			-- never planted on top of one of them.
			local wall = {}
			for step = 0, spec.MAX_SHIFTS do
				table.insert(wall, Vector2.new(first.at.X, first.at.Y + step * spec.SHIFT_STUDS))
			end
			local blocked = nil
			for _, row in ipairs(Build.avenuePlan(anchor, CFG, wall)) do
				if row.index == first.index then
					blocked = row
				end
			end
			expect(blocked).to.be.ok()
			expect((blocked :: any).dropped).to.equal(true)

			-- AND THE WHOLE PLAN, SHIFTS INCLUDED, STAYS OUT OF THE YARD, THE PADS, THE BAYS, THE
			-- ROAD AND THE HOUSE -- the research note's target 5, asserted on where a tree ENDS UP
			-- and not on the slot table it started from (finding 3). Driven with a trunk on EVERY
			-- nominal slot, so every surviving row in this plan is a shifted one.
			local onEvery = {}
			for _, row in ipairs(clear) do
				table.insert(onEvery, row.at)
			end
			local shoved = Build.avenuePlan(anchor, CFG, onEvery)
			local sawShift = false
			for _, row in ipairs(shoved) do
				if not row.dropped then
					expect(row.shifted > 0).to.equal(true)
					sawShift = true
					expect(Build.plantable(row.at, anchor, CFG)).to.equal(true)
				end
			end
			expect(sawShift).to.equal(true)
			-- ...and two avenue trees never land on each other.
			for i = 1, #clear do
				for j = i + 1, #clear do
					expect((clear[i].at - clear[j].at).Magnitude >= spec.KEEP_OFF_TREES_STUDS).to.equal(true)
				end
			end
		end)

		it("builds the pole on the ground it is given, with the flag hanging off the mast", function()
			local folder = Instance.new("Folder")
			local ground = 160.5
			local built = Build.build(
				folder,
				anchor,
				CFG,
				nil,
				{
					groundAt = function()
						return ground
					end,
				} :: any
			)
			local pole = built:FindFirstChild("Flagpole")
			expect(pole).to.be.ok()
			local mast = (pole :: Instance):FindFirstChild("Mast") :: BasePart
			local finial = (pole :: Instance):FindFirstChild("Finial") :: BasePart
			local field = (pole :: Instance):FindFirstChild("FlagField") :: BasePart
			local kerb = (pole :: Instance):FindFirstChild("Kerb") :: BasePart
			expect(mast).to.be.ok()
			-- A CYLINDER'S LENGTH IS ITS X and the mast is turned upright, so its HEIGHT is Size.X.
			expect(math.abs(mast.Size.X - CFG.FLAGPOLE.HEIGHT_STUDS) < 1e-3).to.equal(true)
			-- ITS FOOT IS ON THE GROUND THE READER GAVE, not on the anchor's own Y, and not centred
			-- on it: this is task 186's rule for the trucks, said about a pole.
			expect(math.abs((mast.Position.Y - CFG.FLAGPOLE.HEIGHT_STUDS / 2) - ground) < 1e-3).to.equal(true)
			-- THE KERB IS A TURNED CYLINDER TOO, so its DRAWN height is `BASE_HEIGHT_STUDS` and its
			-- `Size.Y` is the disc's width: the bound is the number the config states.
			expect(math.abs((kerb.Position.Y - CFG.FLAGPOLE.BASE_HEIGHT_STUDS / 2) - ground) < 1e-3).to.equal(true)
			-- THE BALL IS ON TOP OF THE MAST and the flag's top edge is just under it.
			expect(finial.Position.Y > ground + CFG.FLAGPOLE.HEIGHT_STUDS).to.equal(true)
			local flagTop = field.Position.Y + field.Size.Y / 2
			expect(
				math.abs(flagTop - (ground + CFG.FLAGPOLE.HEIGHT_STUDS - CFG.FLAGPOLE.FLAG_TOP_BELOW_FINIAL_STUDS))
					< 1e-3
			).to.equal(true)
			-- AND ITS HOIST EDGE TOUCHES THE MAST: a flag floating beside its pole is the defect
			-- this assertion exists for.
			local hoist = field.Position.X - field.Size.X / 2
			expect(math.abs(hoist - (mast.Position.X + CFG.FLAGPOLE.DIAMETER_STUDS / 2)) < 1e-3).to.equal(true)
			-- NOTHING OF THE POLE IS UNDER THE SURFACE IT WAS SEATED ON, and the bound is each
			-- piece's own drawn extent: a cylinder's LENGTH is its X and the mast is turned upright,
			-- so a single "half the biggest side" rule would read the kerb as 1.5 studs buried when
			-- it is 0.4 studs tall. `GetBoundingBox` asks the engine where the piece really is.
			for _, piece in ipairs((pole :: Instance):GetChildren()) do
				if piece:IsA("BasePart") then
					local at, size = piece.CFrame, piece.Size
					local lowest = math.huge
					for sx = -1, 1, 2 do
						for sy = -1, 1, 2 do
							for sz = -1, 1, 2 do
								local corner =
									at:PointToWorldSpace(Vector3.new(sx * size.X / 2, sy * size.Y / 2, sz * size.Z / 2))
								lowest = math.min(lowest, corner.Y)
							end
						end
					end
					expect(lowest >= ground - 0.01).to.equal(true)
				end
			end
			folder:Destroy()
		end)

		it("plants the avenue when there are templates, and nothing when there are none", function()
			-- NO TEMPLATES, NO AVENUE -- and no error: `Workspace.LobbyAssets` exists in the Forest
			-- Test place and not in DEV, which is the branch every tree in this lobby already takes.
			local bare = Instance.new("Folder")
			local builtBare = Build.build(bare, anchor, CFG, nil, nil)
			expect(builtBare:FindFirstChild("Avenue")).to.equal(nil)
			-- ...but the POLE is built from Parts, so it is there either way.
			expect(builtBare:FindFirstChild("Flagpole")).to.be.ok()
			bare:Destroy()

			-- WITH a folder of templates of our own: one birch model, named as the allow-list names
			-- it, so this spec needs no Workspace content at all.
			local templates = Instance.new("Folder")
			local trees = Instance.new("Folder")
			trees.Name = Data.TEMPLATE.TREES
			trees.Parent = templates
			local species = nil
			for _, row in ipairs(CFG.TREELINE.SPECIES) do
				if row.KIND == CFG.AVENUE.KIND then
					species = row
				end
			end
			local model = Instance.new("Model")
			model.Name = (species :: any).MODEL
			local trunk = Instance.new("Part")
			trunk.Name = "Trunk"
			trunk.Size = Vector3.new(2, 70, 2)
			trunk.CFrame = CFrame.new(0, 35, 0)
			trunk.Anchored = true
			trunk.Parent = model
			model.PrimaryPart = trunk
			model.Parent = trees

			local folder = Instance.new("Folder")
			local built = Build.build(
				folder,
				anchor,
				CFG,
				templates,
				{
					groundAt = function()
						return 149.25
					end,
				} :: any
			)
			local planted = built:FindFirstChild("Avenue")
			expect(planted).to.be.ok()
			-- AS MANY TREES AS THERE ARE NON-GAP SLOTS, less any the forest ring pushed out -- and
			-- the count is in `Lobby.stats()` rather than inferred, so a drop is visible.
			local made = Build.stats()
			expect(made.avenueTrees + made.avenueDropped).to.equal(#CFG.AVENUE.SLOTS - made.avenueGaps)
			expect(made.avenueGaps >= 1).to.equal(true)
			expect(#(planted :: Instance):GetChildren()).to.equal(made.avenueTrees)
			-- EVERY TRUNK THAT WAS PLANTED IS SOMEWHERE A TREE MAY STAND -- off the road AND off the
			-- yard, the pads, the bays and the house -- measured where it ENDED UP rather than where
			-- its row said it would be (review round 1, finding 3).
			for _, tree in ipairs((planted :: Instance):GetChildren()) do
				local at = (tree :: Model):GetPivot().Position
				expect(Build.plantable(Vector2.new(at.X, at.Z), anchor, CFG)).to.equal(true)
			end
			folder:Destroy()
			templates:Destroy()
		end)
	end)
end
