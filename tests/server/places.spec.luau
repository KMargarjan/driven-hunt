--!nocheck
-- Task 193: KAREN'S FOUR DRIVE PLACES -- what is planted around each drive line, and the one rule
-- that keeps the shooting lanes clear.
--
-- EVERYTHING IN HERE RUNS WITH NO WORLD. `Places` (shared) is pure by construction, so these cases
-- assert where all ~1,800 trees go without a Studio, and the server half is driven through a fake
-- ground reader -- which is the whole reason task 199's split was repeated here.
--
-- Note: docs/research/2026-10-17-four-driven-hunt-places.md
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
	local Plan = require(ReplicatedStorage:WaitForChild("Places"))
	local Forest = require(ReplicatedStorage:WaitForChild("ForestTest"))
	local Planter = require(ServerScriptService:WaitForChild("Places"))

	-- ---------------------------------------------------------------- the four places exist

	describe("the four places", function()
		it("dresses every layout that is not the road, and dresses the road with nothing", function()
			-- KAREN ASKED FOR FOUR (2026-10-15). Three of them are planted; `road` is task 179's
			-- world kept number for number (BRIEF decision 3), so it has no plan at all -- and that
			-- absence is asserted, not assumed.
			expect(#Forest.LAYOUT_ORDER).to.equal(4)
			expect(Plan.planFor("road")).to.equal(nil)
			local dressed = 0
			for _, name in ipairs(Forest.LAYOUT_ORDER) do
				local plan = Plan.planFor(name)
				if plan ~= nil then
					dressed += 1
					expect(plan.halfStripStuds > 0).to.equal(true)
					expect(plan.spacingStuds > 0).to.equal(true)
					expect(plan.beltStuds >= 0).to.equal(true)
					expect(plan.bands.herbStuds < plan.bands.shrubStuds).to.equal(true)
				end
			end
			expect(dressed).to.equal(3)
			TestKit.note(string.format("places: %s, %d dressed", table.concat(Forest.LAYOUT_ORDER, ", "), dressed))
		end)

		it("gives each place the strip width its reference frame shows", function()
			-- THE NUMBERS KAREN'S FRAMES AND THE FORESTRY SOURCES GIVE, at 0.28 m per stud:
			--   * the cut line a `Schussschneise` of 15-25 m (the dispatch), 10-15 m preferred,
			--   * the forest road a `Rueckegasse` of 3-4 m, "at least four metres" recommended.
			-- The strip is `halfStripStuds * 2`; the CLEAR ground is wider by `LANE_STUDS` each side.
			local metres = 0.28
			local ride = Plan.planFor("ride")
			local track = Plan.planFor("track")
			local rideM = ride.halfStripStuds * 2 * metres
			local trackM = track.halfStripStuds * 2 * metres
			expect(rideM >= 15).to.equal(true)
			expect(rideM <= 25).to.equal(true)
			expect(trackM >= 4).to.equal(true)
			expect(trackM <= 8).to.equal(true)
			-- ...AND THE FOREST ROAD IS THE NARROW ONE. Karen asked for two roads that are not the
			-- same place, and this is the measurable half of the difference.
			expect(track.halfStripStuds < ride.halfStripStuds).to.equal(true)
			TestKit.note(string.format("strips: cut line %.1f m, forest road %.1f m", rideM, trackM))
		end)

		it("plants nothing north of the field edge, because the field is the point", function()
			-- KAREN'S PLACE 2 is *"forest ending then field and then again forest"*: the far forest is
			-- this world's real wood and the FIELD is the open ground in front of the guns. One tree
			-- planted north of this line and it stops being a field.
			local edge = Plan.planFor("edge")
			expect(edge.northBeltStuds).to.equal(0)
			local layout = Forest.layoutNamed("edge")
			local north = 0
			for _, item in ipairs(Plan.plant(layout, edge)) do
				if item.z > Forest.roadZ(item.x, layout) then
					north += 1
				end
			end
			expect(north).to.equal(0)
		end)

		it("leaves 141 m of open field between the guns and the wood", function()
			-- MEASURED IN THE PLACE, 2026-10-17: the wood's southern face is z -2900 at every column
			-- of this stand span. Karen asked for 80-150 m of field.
			local layout = Forest.layoutNamed("edge")
			local treeLine = -2900
			local metres = (treeLine - layout.centre.Z) * 0.28
			expect(metres >= 80).to.equal(true)
			expect(metres <= 150).to.equal(true)
			TestKit.note(string.format("field: %.0f m from the guns to the tree line", metres))
		end)
	end)

	-- ---------------------------------------------------------------- the lane rule

	describe("the shooting lanes", function()
		it("has no tree in any lane, in any place", function()
			-- THE DISPATCH'S *"no trees in the shooting lanes, no stands inside trunks"*, asserted
			-- over EVERY planting of every place rather than sampled. This is the case the whole
			-- "the strip is a subtraction" pattern exists to make provable.
			local checked, worst, worstPlace = 0, math.huge, "-"
			for _, name in ipairs(Forest.LAYOUT_ORDER) do
				local plan = Plan.planFor(name)
				local layout = Forest.layoutNamed(name)
				if plan ~= nil and layout ~= nil then
					for _, item in ipairs(Plan.plant(layout, plan)) do
						checked += 1
						expect(Plan.inLane(item.x, item.z, layout, plan)).to.equal(false)
						local gap = math.abs(item.z - Forest.roadZ(item.x, layout))
						if gap < worst then
							worst, worstPlace = gap, name
						end
					end
				end
			end
			expect(checked > 100).to.equal(true)
			TestKit.note(string.format("%d plantings, nearest to a line %.1f studs (%s)", checked, worst, worstPlace))
		end)

		it("keeps every tree clear of every stand circle", function()
			-- A STAND IS A SPOT A HUNTER IS LOCKED TO (Karen, task 179: *"just a hunter no treestand
			-- anything"*), and `PICK.radiusStuds` is the circle. A tree inside one is a hunter
			-- standing in a trunk.
			local radius = Forest.PICK.radiusStuds
			for _, name in ipairs(Forest.LAYOUT_ORDER) do
				local plan = Plan.planFor(name)
				local layout = Forest.layoutNamed(name)
				if plan ~= nil and layout ~= nil then
					local list = Plan.plant(layout, plan)
					for index = 1, layout.standCount do
						local stand = Forest.standPosition(index, layout)
						for _, item in ipairs(list) do
							local dx, dz = item.x - stand.X, item.z - stand.Z
							expect(math.sqrt(dx * dx + dz * dz) > radius).to.equal(true)
						end
					end
				end
			end
		end)

		it("answers the lane against the line's own z at that x, so a curve gets a curved strip", function()
			-- `road` has amplitude 30, so this is the one case where "distance from the line" and
			-- "distance from centre.Z" are different numbers. The rule has to use the first.
			local road = Forest.layoutNamed("road")
			local plan = { halfStripStuds = 10 }
			local x = road.centre.X + 110 -- a quarter wavelength or so off centre
			local lineZ = Forest.roadZ(x, road)
			expect(lineZ ~= road.centre.Z).to.equal(true)
			expect(Plan.inLane(x, lineZ, road, plan)).to.equal(true)
			expect(Plan.inLane(x, road.centre.Z, road, plan)).to.equal(false)
		end)
	end)

	-- ---------------------------------------------------------------- the plan itself

	describe("the plan", function()
		it("is the same forest every time, from the same seed", function()
			-- REPRODUCIBLE FROM A COMMIT is what lets Karen judge a frame and somebody else rebuild
			-- it. Two calls, item for item.
			local layout = Forest.layoutNamed("ride")
			local plan = Plan.planFor("ride")
			local a, b = Plan.plant(layout, plan), Plan.plant(layout, plan)
			expect(#a).to.equal(#b)
			expect(#a > 0).to.equal(true)
			for index, item in ipairs(a) do
				expect(b[index].model).to.equal(item.model)
				expect(b[index].x).to.equal(item.x)
				expect(b[index].z).to.equal(item.z)
				expect(b[index].scale).to.equal(item.scale)
			end
			TestKit.note(string.format("cut line: %d plantings, reproducible", #a))
		end)

		it("stays under the capacity it declares before it runs", function()
			-- THE BOUND IS KNOWN BEFORE ANYTHING IS CLONED, which is what stops a density tweak
			-- quietly becoming a twenty-thousand-part world.
			local total = 0
			for _, name in ipairs(Forest.LAYOUT_ORDER) do
				local plan = Plan.planFor(name)
				local layout = Forest.layoutNamed(name)
				if plan ~= nil and layout ~= nil then
					local list = Plan.plant(layout, plan)
					local cap = Plan.capacity(layout, plan)
					expect(#list <= cap).to.equal(true)
					total += #list
				end
			end
			expect(total > 300).to.equal(true)
			expect(total < 6000).to.equal(true)
			TestKit.note(string.format("all places: %d plantings", total))
		end)

		it("puts the young growth at the edge and the big trees behind it", function()
			-- THE GRADED EDGE (`Krautsaum`, `Strauchmantel`, `Baummantel`): the band nearest the
			-- strip must be the SMALL one, in every place. This is what makes ref-5's young pines and
			-- ref-1's young firs come out of the same table.
			for _, name in ipairs(Forest.LAYOUT_ORDER) do
				local plan = Plan.planFor(name)
				if plan ~= nil then
					expect(plan.shrubScale[2] <= plan.woodScale[1]).to.equal(true)
				end
			end
			local layout = Forest.layoutNamed("track")
			local plan = Plan.planFor("track")
			local counts = { herb = 0, shrub = 0, wood = 0 }
			local biggestShrub, smallestWood = 0, math.huge
			for _, item in ipairs(Plan.plant(layout, plan)) do
				counts[item.band] += 1
				if item.band == "shrub" then
					biggestShrub = math.max(biggestShrub, item.scale)
				elseif item.band == "wood" then
					smallestWood = math.min(smallestWood, item.scale)
				end
			end
			expect(counts.herb > 0).to.equal(true)
			expect(counts.shrub > 0).to.equal(true)
			expect(counts.wood > 0).to.equal(true)
			expect(biggestShrub <= smallestWood).to.equal(true)
			TestKit.note(
				string.format("forest road bands: herb %d, shrub %d, wood %d", counts.herb, counts.shrub, counts.wood)
			)
		end)

		it("only names species this world actually holds", function()
			-- A NAME NOT IN `OurForest` PLANTS NOTHING, so a typo here is a thinner forest and never
			-- a crash -- but a typo is still a defect, and this is where it is caught.
			local known = {}
			for _, names in pairs(Plan.SPECIES) do
				for _, name in ipairs(names) do
					known[name] = true
				end
			end
			for _, name in ipairs(Forest.LAYOUT_ORDER) do
				local plan = Plan.planFor(name)
				local layout = Forest.layoutNamed(name)
				if plan ~= nil and layout ~= nil then
					for _, item in ipairs(Plan.plant(layout, plan)) do
						expect(known[item.model]).to.equal(true)
					end
				end
			end
			-- ...and every GROUP a band draws from has to exist too.
			for _, name in ipairs(Forest.LAYOUT_ORDER) do
				local plan = Plan.planFor(name)
				if plan ~= nil then
					for _, band in ipairs({ "herb", "shrub", "wood" }) do
						for _, row in ipairs(plan[band]) do
							expect(#Plan.SPECIES[row.group] > 0).to.equal(true)
						end
					end
				end
			end
		end)

		it("draws a species from a mix in proportion to its weight", function()
			local rows = { { group = "a", weight = 1 }, { group = "b", weight = 3 } }
			expect(Plan.speciesFrom(rows, 0)).to.equal("a")
			expect(Plan.speciesFrom(rows, 0.24)).to.equal("a")
			expect(Plan.speciesFrom(rows, 0.26)).to.equal("b")
			expect(Plan.speciesFrom(rows, 0.999)).to.equal("b")
			-- OUT OF RANGE IS CLAMPED, never nil: a spec is allowed to hand this anything.
			expect(Plan.speciesFrom(rows, 1.5)).to.equal("b")
			expect(Plan.speciesFrom(rows, -1)).to.equal("a")
		end)
	end)

	-- ---------------------------------------------------------------- the planter

	describe("the planter", function()
		it("reads the claw fraction from the measured table and zero everywhere else", function()
			-- `tools/forest_claws.json`, measured 2026-10-16: of 61 models, five carry a non-zero
			-- fraction. Everything else is ZERO by the tool's own rule.
			expect(Planter.clawFor("SilverBirch_Var11_LOD_0")).to.equal(0.0425)
			expect(Planter.clawFor("SilverBirch_Var07_LOD_0")).to.equal(0.0562)
			expect(Planter.clawFor("Old_Spruce_Tree_Var02_LOD_0")).to.equal(0)
			expect(Planter.clawFor("a model that does not exist")).to.equal(0)
			local nonZero = 0
			for _, value in pairs(Planter.CLAW_FRACTION) do
				expect(value > 0).to.equal(true)
				expect(value < 0.1).to.equal(true)
				nonZero += 1
			end
			expect(nonZero).to.equal(5)
		end)

		it("samples the ground on a 5 x 5 grid over the footprint, corners included", function()
			-- LESSON L-024 and standing rule E: the ground is read at EVERY footprint sample, never
			-- at the pivot. Driven with a fake reader so the grid itself is what is asserted.
			local seen = {}
			local grounds = Planter.groundsUnder({
				minX = 0,
				minZ = 0,
				maxX = 8,
				maxZ = 4,
				minY = 0,
				maxY = 1,
			}, function(x, z)
				table.insert(seen, string.format("%.1f,%.1f", x, z))
				return 100 + x
			end)
			expect(#grounds).to.equal(25)
			expect(#seen).to.equal(25)
			-- the four corners are in the grid
			local function has(point)
				for _, got in ipairs(seen) do
					if got == point then
						return true
					end
				end
				return false
			end
			expect(has("0.0,0.0")).to.equal(true)
			expect(has("8.0,0.0")).to.equal(true)
			expect(has("0.0,4.0")).to.equal(true)
			expect(has("8.0,4.0")).to.equal(true)
			-- ...and the LOWEST reading is what `TreeGround.liftTo` will use.
			local low = math.huge
			for _, y in ipairs(grounds) do
				low = math.min(low, y)
			end
			expect(low).to.equal(100)
		end)

		it("drops a sample the world cannot answer rather than inventing a height", function()
			local grounds = Planter.groundsUnder({
				minX = 0,
				minZ = 0,
				maxX = 4,
				maxZ = 4,
				minY = 0,
				maxY = 1,
			}, function(x, _z)
				return if x > 2 then 50 else nil
			end)
			expect(#grounds > 0).to.equal(true)
			expect(#grounds < 25).to.equal(true)
			for _, y in ipairs(grounds) do
				expect(y).to.equal(50)
			end
		end)

		it("measures a part's world box with its rotation projected onto the axes", function()
			local part = Instance.new("Part")
			part.Size = Vector3.new(4, 10, 2)
			part.CFrame = CFrame.new(100, 50, -20)
			local box = Planter.boxOf(part)
			expect(box.minX).to.equal(98)
			expect(box.maxX).to.equal(102)
			expect(box.minY).to.equal(45)
			expect(box.maxY).to.equal(55)
			-- TURNED A QUARTER TURN, the x and z reaches swap -- which is the whole reason the box is
			-- projected and not read off `Size`.
			part.CFrame = CFrame.new(100, 50, -20) * CFrame.Angles(0, math.pi / 2, 0)
			local turned = Planter.boxOf(part)
			expect(math.abs((turned.maxX - turned.minX) - 2) < 0.001).to.equal(true)
			expect(math.abs((turned.maxZ - turned.minZ) - 4) < 0.001).to.equal(true)
			part:Destroy()
		end)

		it("takes the trunk's footprint and not the crown's", function()
			-- TASK 196 PART 3c REPORTED ZERO FLOATING TREES by measuring the ground under the canopy,
			-- twelve studs away and down a bank. The rule is "the part called Trunk".
			local model = Instance.new("Model")
			local crown = Instance.new("Part")
			crown.Name = "Leaves"
			crown.Size = Vector3.new(26, 20, 26)
			crown.CFrame = CFrame.new(0, 40, 0)
			crown.Parent = model
			local trunk = Instance.new("Part")
			trunk.Name = "Trunk.004"
			trunk.Size = Vector3.new(6, 30, 6)
			trunk.CFrame = CFrame.new(0, 15, 0)
			trunk.Parent = model
			local footprint, whole = Planter.trunkBox(model)
			expect(footprint).never.to.equal(nil)
			expect(whole).never.to.equal(nil)
			expect(footprint.maxX - footprint.minX).to.equal(6)
			expect(whole.maxX - whole.minX).to.equal(26)
			expect(whole.maxY).to.equal(50)
			model:Destroy()
		end)

		it("ignores an invisible pad when it measures, and refuses to let it stop a bullet", function()
			-- MEASURED IN THIS WORLD: `Old_Spruce_Tree_Var02_LOD_0` carries a `Basepart` with
			-- `CanCollide = false` and `CanQuery = TRUE` -- an invisible pad that eats a shot, which
			-- is lesson L-060 exactly (task 149 lost 4 of 5 shots in foliage).
			local model = Instance.new("Model")
			local pad = Instance.new("Part")
			pad.Name = "Basepart"
			pad.Transparency = 1
			pad.CanCollide = false
			pad.CanQuery = true
			pad.Size = Vector3.new(40, 1, 40)
			pad.CFrame = CFrame.new(0, -20, 0)
			pad.Parent = model
			local trunk = Instance.new("Part")
			trunk.Name = "Trunk"
			trunk.CanCollide = true
			trunk.CanQuery = true
			trunk.Size = Vector3.new(4, 30, 4)
			trunk.CFrame = CFrame.new(0, 15, 0)
			trunk.Parent = model
			local leaf = Instance.new("Part")
			leaf.Name = "Leaves"
			leaf.CanCollide = false
			leaf.CanQuery = true
			leaf.Size = Vector3.new(20, 20, 20)
			leaf.CFrame = CFrame.new(0, 40, 0)
			leaf.Parent = model

			local footprint = Planter.trunkBox(model)
			-- the pad is below everything and 40 studs across; it must not be the footprint
			expect(footprint.maxX - footprint.minX).to.equal(4)

			local changed = Planter.quieten(model)
			expect(changed).to.equal(2)
			expect(pad.CanQuery).to.equal(false)
			expect(leaf.CanQuery).to.equal(false)
			-- THE TRUNK STILL STOPS A BULLET, which it must.
			expect(trunk.CanQuery).to.equal(true)
			expect(trunk.CanCollide).to.equal(true)
			expect(trunk.Anchored).to.equal(true)
			model:Destroy()
		end)

		it("plants nothing at all when the templates are not in this place", function()
			-- THE DEV CASE. Neither `OurForest` nor `Session` exists there, and the answer is a
			-- report with a reason -- not a crash, and not a folder.
			local empty = Instance.new("Folder")
			expect(#Planter.templates(empty)).to.equal(0)
			local report = Planter.build(function()
				return 100
			end, empty)
			expect(report.reason).to.equal("no-templates")
			expect(report.planted).to.equal(0)
			expect(empty:FindFirstChild(Planter.FOLDER)).to.equal(nil)
			empty:Destroy()
		end)
	end)
end
