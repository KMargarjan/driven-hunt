--!nocheck
-- Task 193: KAREN'S FOUR DRIVE PLACES -- what is planted around each drive line, and the one rule
-- that keeps the shooting lanes clear.
--
-- EVERYTHING IN HERE RUNS WITH NO WORLD. `Places` (shared) is pure by construction, so these cases
-- assert where all ~3,000 trees go without a Studio, and the server half is driven through a fake
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
	local Ground = require(ServerScriptService.Places:WaitForChild("Ground"))
	local TreeGround = require(ReplicatedStorage:WaitForChild("TreeGround"))
	local LobbyCfg = require(ReplicatedStorage:WaitForChild("Lobby"))

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

		it("leaves Karen's 80-150 m of open field between the guns and the wood", function()
			-- MEASURED IN THE PLACE, 2026-10-17: the wood's southern face is z -2900 at every column
			-- of this stand span. Karen asked for 80-150 m of field.
			--
			-- IT IS 98 m AND NOT 140, AND A FRAME IS WHY. The line sat at z -3400 (140 m) and the
			-- hunter's-eye frame came back with the ground rising in front of him -- a ray north from
			-- eye height died on terrain at 60 studs, so he could see neither the field nor the wood.
			-- 120 candidate lines were scored and this is the northernmost where EVERY stand sees the
			-- wood's face; the field it gives is 98 m, still inside her range.
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
		it("has no tree in ANY place's lane -- every planting against every layout", function()
			-- THE DISPATCH'S *"no trees in the shooting lanes, no stands inside trunks"*, asserted over
			-- EVERY planting of every place against EVERY layout, rather than against the one the trees
			-- came from.
			--
			-- THE CROSS-PLACE HALF IS THE WHOLE POINT, AND IT USED TO BE UNTESTABLE (Reviewer, round 2,
			-- finding 1). The old case looped `LAYOUT_ORDER` and compared each place's trees against its
			-- OWN line, so it could not fail -- and what it could not see was real: the cut line's north
			-- belt reaches 684 studs and the forest road's line is 600 studs away, so one place's wood was
			-- planted through the other's track and across five of its six stands.
			--
			-- IT ALSO DOES THE ARITHMETIC ITSELF (round 1, finding 3): asking `Plan.inLane` alone proves
			-- only that the planner called its own predicate.
			local checked, worst, worstPair = 0, math.huge, "-"
			for _, from in ipairs(Forest.LAYOUT_ORDER) do
				local plan = Plan.planFor(from)
				local grown = Forest.layoutNamed(from)
				if plan ~= nil and grown ~= nil then
					for _, item in ipairs(Plan.plant(grown, plan)) do
						checked += 1
						for _, against in ipairs(Forest.LAYOUT_ORDER) do
							local other = Forest.layoutNamed(against)
							local clear = Plan.laneHalfWidth(Plan.planFor(against))
							local gap = math.abs(item.z - Forest.roadZ(item.x, other))
							expect(gap > clear).to.equal(true)
							expect(Plan.inLane(item.x, item.z, other, Plan.planFor(against))).to.equal(false)
							if gap - clear < worst then
								worst, worstPair = gap - clear, from .. " vs " .. against
							end
						end
						expect(Plan.clearOfEveryLane(item.x, item.z)).to.equal(true)
					end
				end
			end
			expect(checked > 100).to.equal(true)
			TestKit.note(
				string.format(
					"%d plantings x %d layouts, tightest margin %.1f studs (%s)",
					checked,
					#Forest.LAYOUT_ORDER,
					worst,
					worstPair
				)
			)
		end)

		it("keeps every tree clear of EVERY place's stand circles", function()
			-- A STAND IS A SPOT A HUNTER IS LOCKED TO (Karen, task 179: *"just a hunter no treestand
			-- anything"*), and `PICK.standRadiusStuds` is the circle. A tree inside one is a hunter
			-- standing in a trunk -- and it does not matter which place planted it (round 2, finding 1).
			--
			-- THE TWO NUMBERS ARE ONE FACT AND ARE CHECKED, NOT DESCRIBED: `LANE_STUDS` is the stand
			-- radius, so the lane rule alone already clears every circle on every line.
			expect(Plan.LANE_STUDS).to.equal(Forest.PICK.standRadiusStuds)
			local radius = Forest.PICK.standRadiusStuds
			local worst, worstAt = math.huge, "-"
			for _, from in ipairs(Forest.LAYOUT_ORDER) do
				local plan = Plan.planFor(from)
				local grown = Forest.layoutNamed(from)
				if plan ~= nil and grown ~= nil then
					local list = Plan.plant(grown, plan)
					for _, against in ipairs(Forest.LAYOUT_ORDER) do
						local other = Forest.layoutNamed(against)
						for index = 1, other.standCount do
							local stand = Forest.standPosition(index, other)
							for _, item in ipairs(list) do
								local dx, dz = item.x - stand.X, item.z - stand.Z
								local away = math.sqrt(dx * dx + dz * dz)
								expect(away > radius).to.equal(true)
								if away < worst then
									worst, worstAt = away, from .. " tree vs " .. against .. " stand " .. index
								end
							end
						end
					end
				end
			end
			TestKit.note(string.format("nearest tree to any stand: %.1f studs (%s), radius %d", worst, worstAt, radius))
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
			-- `deep` IS THE FOURTH BAND (design 10.2); without its row `counts[item.band] += 1` is
			-- `nil + 1` and the case errors (design 10.4 item 2).
			local counts = { herb = 0, shrub = 0, wood = 0, deep = 0 }
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
			expect(counts.deep > 0).to.equal(true)
			TestKit.note(
				string.format(
					"forest road bands: herb %d, shrub %d, wood %d, deep %d",
					counts.herb,
					counts.shrub,
					counts.wood,
					counts.deep
				)
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
					for _, band in ipairs({ "herb", "shrub", "wood", "deep" }) do
						for _, row in ipairs(plan[band]) do
							expect(#Plan.SPECIES[row.group] > 0).to.equal(true)
						end
					end
				end
			end
		end)

		it("never puts two trees in one stump, and the spec measures that itself", function()
			-- DESIGN 10.3: the header claimed Bridson's neighbour test and the first build had none, so
			-- two trees in adjacent cells could land 5 studs apart while a trunk flare is up to 13.6
			-- studs across. The spec builds its OWN grid rather than calling the planner's helper, so a
			-- broken `tooClose` cannot agree with itself.
			for _, name in ipairs(Forest.LAYOUT_ORDER) do
				local plan = Plan.planFor(name)
				local layout = Forest.layoutNamed(name)
				if plan ~= nil and layout ~= nil then
					local trees, ferns = {}, {}
					for _, item in ipairs(Plan.plant(layout, plan)) do
						table.insert(if item.band == "herb" then ferns else trees, item)
					end
					for _, pair in ipairs({ { trees, plan.minGapStuds }, { ferns, 0.5 * plan.fernSpacing } }) do
						local list, gap = pair[1], pair[2]
						local cells, worst = {}, math.huge
						for _, item in ipairs(list) do
							local cx, cz = math.floor(item.x / gap), math.floor(item.z / gap)
							for dx = -1, 1 do
								for dz = -1, 1 do
									for _, other in ipairs(cells[(cx + dx) .. ":" .. (cz + dz)] or {}) do
										local ddx, ddz = other.x - item.x, other.z - item.z
										worst = math.min(worst, math.sqrt(ddx * ddx + ddz * ddz))
									end
								end
							end
							local key = cx .. ":" .. cz
							cells[key] = cells[key] or {}
							table.insert(cells[key], item)
						end
						if #list > 1 then
							expect(worst >= gap).to.equal(true)
						end
					end
				end
			end
		end)

		it("plants only on the ground the BRIEF surveyed", function()
			-- DESIGN 10.5: the first build ran out to `span + beltStuds`, which for the forest road was
			-- x 4245..5355 against a plot measured over 820 studs. An unsurveyed strip is where an
			-- existing `Session` bush could be standing, and "every tree is on the ground" must not be
			-- claimed over ground nobody looked at.
			for _, name in ipairs(Forest.LAYOUT_ORDER) do
				local plan = Plan.planFor(name)
				local layout = Forest.layoutNamed(name)
				if plan ~= nil and layout ~= nil then
					local plot = Plan.plotOf(layout, plan)
					for _, item in ipairs(Plan.plant(layout, plan)) do
						expect(item.x >= plot.minX).to.equal(true)
						expect(item.x <= plot.maxX).to.equal(true)
					end
				end
			end
		end)

		it("keeps the resting wood inside the belt, so a beater has a legal spot to rest in", function()
			-- DESIGN 12.2, and it was missing (Reviewer, round 1, finding 2). `ForestTest.REST.farRoadStuds`
			-- is how far north a resting spot may be, and `restSpot` only accepts one whose nearest solid
			-- thing is within `nearTrunkStuds`. A belt that stops short of `farRoadStuds` leaves the far
			-- half of the resting wood with no trunk in it at all -- i.e. no legal spot.
			for _, name in ipairs(Forest.LAYOUT_ORDER) do
				local plan = Plan.planFor(name)
				if plan ~= nil and plan.northBeltStuds > 0 then
					expect(Forest.REST.farRoadStuds <= plan.northBeltStuds - Plan.LANE_STUDS).to.equal(true)
				end
			end
		end)

		it("musters the beaters in cover, not on another place's track", function()
			-- TASKS.md 193a(a), and the Director asked for it before merge: the cut line's beaters mustered
			-- at z -3920, which is inside the forest road's lane (-3921..-3879) -- they formed up ON that
			-- place's painted track, which is the one thing design 10.2 raised the belt to 640 to prevent.
			-- The cut line moved 40 studs south (z -4540), the only candidate that keeps a 400-stud sight
			-- line at every stand.
			for _, name in ipairs(Forest.LAYOUT_ORDER) do
				local layout = Forest.layoutNamed(name)
				if layout ~= nil and Plan.planFor(name) ~= nil then
					local musterZ = layout.centre.Z + Forest.beaterNorthStuds()
					for _, against in ipairs(Forest.LAYOUT_ORDER) do
						if against ~= name then
							local other = Forest.layoutNamed(against)
							local clear = Plan.laneHalfWidth(Plan.planFor(against))
							-- at the muster's own x span, which is the stands' span
							local span = Forest.standSpan(layout)
							for x = span.minX, span.maxX, 50 do
								expect(math.abs(musterZ - Forest.roadZ(x, other)) > clear).to.equal(true)
							end
						end
					end
				end
			end
			TestKit.note(
				string.format(
					"muster: cut line z %.0f, forest road's lane edge %.0f",
					Forest.layoutNamed("ride").centre.Z + Forest.beaterNorthStuds(),
					Forest.layoutNamed("track").centre.Z + Plan.laneHalfWidth(Plan.planFor("track"))
				)
			)
		end)

		it("carries the north belt all the way to where the beaters muster", function()
			-- DESIGN 10.2: with a 230-stud belt the beaters formed up in 306 studs of bare grass that a
			-- hunter looks straight up the ride at, and `restSpot` had no legal spot out there at all
			-- (`REST.farRoadStuds` 425 against `nearTrunkStuds` 22). The belt now reaches
			-- `beaterNorthStuds()` plus a run-out.
			local muster = Forest.beaterNorthStuds()
			for _, name in ipairs({ "ride", "track" }) do
				local plan = Plan.planFor(name)
				local layout = Forest.layoutNamed(name)
				local lane = plan.halfStripStuds + Plan.LANE_STUDS
				expect(lane + plan.northBeltStuds >= muster).to.equal(true)
				-- ...and a tree really is planted out there, which the arithmetic alone does not prove.
				local far = 0
				for _, item in ipairs(Plan.plant(layout, plan)) do
					if item.side > 0 and math.abs(item.z - Forest.roadZ(item.x, layout)) >= muster - 60 then
						far += 1
					end
				end
				expect(far > 0).to.equal(true)
				TestKit.note(string.format("%s: %d trees within 60 studs of the beaters' muster", name, far))
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

		it("takes BOTH properties off a visible, COLLIDING branch -- the task 260 case", function()
			-- MEASURED WITH A CONTROL IN THE FOREST TEST on 2026-10-25
			-- (`driven-hunt-runs/260-why.luau`, read-only): a ray stops on a part with
			-- `CanQuery = false` while that part still COLLIDES, and does not stop on the same
			-- part's non-colliding sibling. So the old rule -- clear `CanQuery` on anything that does
			-- not collide -- only ever touched parts that were already harmless, and the 127
			-- colliding `Branch` parts in Karen's wood went on killing shots. That is L-060
			-- recurring as 258a(f).
			local model = Instance.new("Model")
			local branch = Instance.new("Part")
			branch.Name = "Branch.001"
			branch.Transparency = 0 -- VISIBLE, so the old invisibility arm cannot reach it
			branch.CanCollide = true -- and COLLIDING, which is what made it stop rays
			branch.CanQuery = false -- already "fixed" by the old rule, and still stopping bullets
			branch.Parent = model
			local trunk = Instance.new("Part")
			trunk.Name = "SM_Trunk"
			trunk.CanCollide = true
			trunk.CanQuery = true
			trunk.Parent = model

			-- ONE property to change on the branch: its collision. `CanQuery` was already false.
			expect(Planter.unblockFoliage(model)).to.equal(1)
			expect(branch.CanQuery).to.equal(false)
			expect(branch.CanCollide).to.equal(false)
			-- THE TRUNK IS UNTOUCHED, which is the other half of the Director's sentence.
			expect(trunk.CanQuery).to.equal(true)
			expect(trunk.CanCollide).to.equal(true)
			model:Destroy()
		end)

		it("takes both off a queryable leaf, which is what Karen's Session trees carry", function()
			-- The other half of the measurement: 623 parts in `Workspace.Session` were
			-- `CanQuery = true`, `CanCollide = false` -- 357 `OuterLeaves` and 266 bushes.
			local folder = Instance.new("Folder")
			for _, name in ipairs({ "OuterLeaves", "Bush4" }) do
				local leaf = Instance.new("Part")
				leaf.Name = name
				leaf.CanQuery = true
				leaf.CanCollide = false
				leaf.Parent = folder
			end
			-- A FOLDER, NOT A MODEL, because the standing Studio content is folders -- and the sweep
			-- at boot is handed those same instances.
			expect(Planter.unblockFoliage(folder)).to.equal(2)
			for _, leaf in ipairs(folder:GetChildren()) do
				expect((leaf :: any).CanQuery).to.equal(false)
				expect((leaf :: any).CanCollide).to.equal(false)
			end
			-- IDEMPOTENT: a second boot in the same session changes nothing and says so.
			expect(Planter.unblockFoliage(folder)).to.equal(0)
			folder:Destroy()
		end)

		it("finds EVERY tree folder, including a duplicate name", function()
			-- MEASURED IN THE FOREST TEST on 2026-10-25: `Workspace` has **two** children called
			-- `Session`, and `Places.templates`' `FindFirstChild` can only answer one -- which is why
			-- the first sweep left 41 queryable leaves standing in the second. A name lookup cannot
			-- see a duplicate, so the sweep walks the children instead.
			local root = Instance.new("Folder")
			for _, name in ipairs({ "Session", "Session", "OurForest", "LobbyAssets", "SomethingElse" }) do
				local folder = Instance.new("Folder")
				folder.Name = name
				folder.Parent = root
			end
			local found = Planter.foliageRoots(root)
			expect(#found).to.equal(4)
			local sessions = 0
			for _, instance in ipairs(found) do
				expect(instance.Name).never.to.equal("SomethingElse")
				if instance.Name == "Session" then
					sessions += 1
				end
			end
			expect(sessions).to.equal(2)
			root:Destroy()
		end)

		it("calls a leaf a leaf and never calls a trunk one", function()
			-- THE NAME LIST IS THE ONE THING THIS ARM RESTS ON (see `unblockFoliage`'s header: a
			-- visible colliding leaf is indistinguishable from a trunk by its properties), so the
			-- names MEASURED in Karen's wood are asserted on both sides.
			for _, name in ipairs({
				"OuterLeaves",
				"SM_Leaves",
				"Branch",
				"Branch.001",
				"Branch.002",
				"Bush",
				"Bush1",
				"Bush3",
				"Bush4",
				"SM_Lady_Fern_Var02",
				"Crown",
			}) do
				if not Planter.isFoliageName(name) then
					error(string.format("[places] %q is foliage in this world and the rule does not see it", name))
				end
			end
			for _, name in ipairs({ "Trunk", "SM_Trunk", "CollidePart", "Basepart", "Part", "Stem", "Root" }) do
				if Planter.isFoliageName(name) then
					error(string.format("[places] %q must keep stopping bullets and the rule calls it foliage", name))
				end
			end
		end)

		it("never plants a tree above the ground, on a hillside it has never seen", function()
			-- DESIGN 12.1 CASE 22, and the Reviewer was right that it was missing (round 1, finding 2):
			-- `plantOne` is the function that actually puts a tree on the ground, and nothing asserted it.
			-- Claim 4 of round 1 rested entirely on one live run.
			--
			-- NO WORLD IS NEEDED: the template is a fake tree and the ground is a fake hillside, so this
			-- drives the real `plantOne` with no Terrain and no Studio.
			local function fakeTree(trunkHeight: number)
				local model = Instance.new("Model")
				local trunk = Instance.new("Part")
				trunk.Name = "Trunk"
				trunk.Size = Vector3.new(6, trunkHeight, 6)
				trunk.CFrame = CFrame.new(0, trunkHeight / 2, 0)
				trunk.Parent = model
				local leaves = Instance.new("Part")
				leaves.Name = "Leaves"
				leaves.CanCollide = false
				leaves.Size = Vector3.new(20, 20, 20)
				leaves.CFrame = CFrame.new(0, trunkHeight, 0)
				leaves.Parent = model
				model.PrimaryPart = trunk
				return model
			end

			local parent = Instance.new("Folder")
			local template = fakeTree(60)
			local item = { model = "Trunk", x = 500, z = -500, scale = 1, yaw = 0, band = "wood", side = -1 }

			-- A GENTLE SLOPE: 0.1 per stud in x, so the 6-stud trunk footprint spans 0.6 studs of ground.
			local made, reason = Planter.plantOne(item, template, parent, function(x, _z)
				return 100 + (x - 500) * 0.1
			end)
			expect(made).never.to.equal(nil)
			expect(reason).to.equal("ok")
			-- THE JUNCTION IS AT OR BELOW THE LOWEST SAMPLE UNDER THE FOOTPRINT, which is the rule, and
			-- the measurement is re-done here off the settled model rather than taken from the planter.
			local trunk, whole = Planter.trunkBox(made)
			local grounds = Planter.groundsUnder(trunk, function(x, _z)
				return 100 + (x - 500) * 0.1
			end)
			local lowest = math.huge
			for _, y in ipairs(grounds) do
				lowest = math.min(lowest, y)
			end
			local junction = trunk.minY + (whole.maxY - trunk.minY) * Planter.clawFor(item.model)
			expect(junction <= lowest + TreeGround.TOLERANCE_STUDS).to.equal(true)
			-- ...and it is SUNK rather than merely not floating: the sink is `TreeGround.sinkFor`.
			expect(junction < lowest).to.equal(true)
			TestKit.note(string.format("plantOne: junction %.3f studs under the lowest sample", lowest - junction))

			-- A FOOTPRINT ACROSS A STEP IS REFUSED AND LEAVES NOTHING BEHIND. A clone that is destroyed
			-- on the way out is the difference between a hole in the forest and a tree in the air.
			local before = #parent:GetChildren()
			local cliff, why = Planter.plantOne(item, template, parent, function(x, _z)
				return if x > 500 then 120 else 100
			end)
			expect(cliff).to.equal(nil)
			expect(why).to.equal("cliff")
			expect(#parent:GetChildren()).to.equal(before)

			-- GROUND THE WORLD CANNOT ANSWER IS ALSO REFUSED, and also leaves nothing.
			local none, noneWhy = Planter.plantOne(item, template, parent, function()
				return nil
			end)
			expect(none).to.equal(nil)
			expect(noneWhy).to.equal("no-ground")
			expect(#parent:GetChildren()).to.equal(before)

			template:Destroy()
			parent:Destroy()
		end)

		it("plants a template at the size it stands, not at the size the number names", function()
			-- TASK 326. KAREN, 2026-11-01: *"also fix broken trees all terai some trees is high in air"*.
			-- `item.scale` is RELATIVE ("1 is the template's own size") and `Model:ScaleTo` is ABSOLUTE.
			-- 52 of the Forest Test's 61 templates stand at a `Scale` that is not 1 -- the birches at
			-- 0.032-0.054 -- so `ScaleTo(0.95)` grew one 25x. FAILS BEFORE THE FIX by a factor of 4.75.
			local function fakeTree(trunkHeight: number)
				local model = Instance.new("Model")
				local trunk = Instance.new("Part")
				trunk.Name = "Trunk"
				trunk.Size = Vector3.new(6, trunkHeight, 6)
				trunk.CFrame = CFrame.new(0, trunkHeight / 2, 0)
				trunk.Parent = model
				local leaves = Instance.new("Part")
				leaves.Name = "Leaves"
				leaves.CanCollide = false
				leaves.Size = Vector3.new(20, 20, 20)
				leaves.CFrame = CFrame.new(0, trunkHeight, 0)
				leaves.Parent = model
				model.PrimaryPart = trunk
				return model
			end

			local parent = Instance.new("Folder")
			local template = fakeTree(60)
			-- THE TEMPLATE DOES NOT STAND AT 1, which is the whole case.
			template:ScaleTo(0.2)
			local standingTrunk = (template:FindFirstChild("Trunk") :: Part).Size.Y
			expect(math.abs(standingTrunk - 12) < 0.01).to.equal(true)

			local item = { model = "Trunk", x = 500, z = -500, scale = 0.95, yaw = 0, band = "wood", side = -1 }
			local made = Planter.plantOne(item, template, parent, function()
				return 100
			end)
			expect(made).never.to.equal(nil)
			local plantedTrunk = ((made :: Model):FindFirstChild("Trunk") :: Part).Size.Y
			TestKit.note(
				string.format(
					"plantOne scale: template trunk %.2f, planted %.2f, wanted %.2f",
					standingTrunk,
					plantedTrunk,
					standingTrunk * item.scale
				)
			)
			expect(math.abs(plantedTrunk - standingTrunk * item.scale) < 0.01).to.equal(true)
			expect(math.abs((made :: Model):GetScale() - 0.2 * item.scale) < 1e-4).to.equal(true)

			template:Destroy()
			parent:Destroy()
		end)

		it("leaves nothing in the air on a step its own allowance accepted", function()
			-- TASK 326, AND IT IS THE HOLE THAT PUT 536 TREES IN THE SKY. The pre-check uses
			-- `stepAllowance` (7 for this tree) and `TreeGround.decide` used to re-check with its own
			-- `CLIFF_STUDS` (4). A 5-stud step is between the two: the spot was accepted, the verdict
			-- said "cliff", `move` was false, and the clone stayed where `PivotTo` had put it -- one
			-- tree-height up. FAILS BEFORE THE FIX with the junction 40 studs above the ground.
			local function fakeTree(trunkHeight: number)
				local model = Instance.new("Model")
				local trunk = Instance.new("Part")
				trunk.Name = "Trunk"
				trunk.Size = Vector3.new(6, trunkHeight, 6)
				trunk.CFrame = CFrame.new(0, trunkHeight / 2, 0)
				trunk.Parent = model
				local leaves = Instance.new("Part")
				leaves.Name = "Leaves"
				leaves.CanCollide = false
				leaves.Size = Vector3.new(20, 20, 20)
				leaves.CFrame = CFrame.new(0, trunkHeight, 0)
				leaves.Parent = model
				model.PrimaryPart = trunk
				return model
			end
			-- A FIVE-STUD STEP ACROSS THE MIDDLE OF THE FOOTPRINT: more than `CLIFF_STUDS`, less than
			-- this tree's own allowance.
			local function step(x: number, _z: number): number?
				return if x > 500 then 105 else 100
			end

			local parent = Instance.new("Folder")
			local template = fakeTree(60)
			local item = { model = "Trunk", x = 500, z = -500, scale = 1, yaw = 0, band = "wood", side = -1 }
			expect(Planter.stepAllowance(70)).to.equal(7)
			expect(TreeGround.CLIFF_STUDS < 5).to.equal(true)

			local made, reason = Planter.plantOne(item, template, parent, step)
			expect(made).never.to.equal(nil)
			-- THE GEOMETRY FIRST, MEASURED WITH THE HELPERS THAT ALREADY EXISTED, so this case fails on
			-- the DEFECT (junction 40 studs up) and not on a helper this task added.
			local trunk, whole = Planter.trunkBox(made :: Model)
			local grounds = Planter.groundsUnder(trunk :: any, step)
			local lowest = math.huge
			for _, y in ipairs(grounds) do
				lowest = math.min(lowest, y)
			end
			local junction = (trunk :: any).minY
				+ ((whole :: any).maxY - (trunk :: any).minY) * Planter.clawFor(item.model)
			TestKit.note(string.format("plantOne on a 5-stud step: junction %.3f above the ground", junction - lowest))
			expect(junction - lowest <= TreeGround.TOLERANCE_STUDS).to.equal(true)
			expect(reason).to.equal("ok")
			expect(Planter.isSeated(made :: Model, step)).to.equal(true)

			template:Destroy()
			parent:Destroy()
		end)

		it("only ever re-seats the world's own foliage, never a building", function()
			-- TASK 326. `STANDING_WOOD` IS NOT `TEMPLATE_SOURCES`: `LobbyAssets` holds the lodge, the
			-- trucks and the two wall heads as well as a tree folder, and lowering a BUILDING onto the
			-- lowest ground under it is a worse bug than the one this task fixes. The three names are
			-- the lobby's own clearing list, asserted rather than described.
			expect(#Planter.STANDING_WOOD).to.equal(3)
			for _, name in ipairs(LobbyCfg.CONFIG.CLEARING.FOLDERS) do
				expect(table.find(Planter.STANDING_WOOD, name) ~= nil).to.equal(true)
			end
			expect(#LobbyCfg.CONFIG.CLEARING.FOLDERS).to.equal(#Planter.STANDING_WOOD)
			expect(table.find(Planter.STANDING_WOOD, "LobbyAssets")).to.equal(nil)

			-- AND THE SWEEP READS THAT LIST, not the templates: a lodge in a `LobbyAssets` folder is
			-- left exactly where it stands even though it is floating.
			local root = Instance.new("Folder")
			local assets = Instance.new("Folder")
			assets.Name = "LobbyAssets"
			assets.Parent = root
			local lodge = Instance.new("Model")
			lodge.Name = "Lodge"
			local wall = Instance.new("Part")
			wall.Name = "Wall"
			wall.Size = Vector3.new(40, 20, 30)
			wall.CFrame = CFrame.new(0, 130, 0)
			wall.Parent = lodge
			lodge.PrimaryPart = wall
			lodge.Parent = assets
			local wood = Instance.new("Folder")
			wood.Name = "OurForest"
			wood.Parent = root
			local flat = function(): number?
				return 100
			end
			local before = wall.Position.Y
			local moved = 0
			for _, source in ipairs(Planter.rootsNamed(root, Planter.STANDING_WOOD)) do
				moved += Planter.reseat(source, flat)
			end
			expect(moved).to.equal(0)
			expect(wall.Position.Y).to.equal(before)
			root:Destroy()
		end)

		it("re-seats a standing tree that hangs in the air and leaves a buried one alone", function()
			-- TASK 326. Four models in `Workspace.Session` -- the bought map's own foliage, saved place
			-- content -- hang 29 to 65 studs above the terrain, and no commit can move saved content.
			-- `Places.reseat` is the run-time sweep that does, and it must only ever LOWER.
			local function treeAt(y: number): Model
				local model = Instance.new("Model")
				local trunk = Instance.new("Part")
				trunk.Name = "Trunk"
				trunk.Size = Vector3.new(6, 60, 6)
				trunk.CFrame = CFrame.new(0, y + 30, 0)
				trunk.Parent = model
				model.PrimaryPart = trunk
				return model
			end
			local flat = function(): number?
				return 100
			end

			local root = Instance.new("Folder")
			local floating = treeAt(140)
			floating.Name = "Floater"
			floating.Parent = root
			local buried = treeAt(96)
			buried.Name = "Buried"
			buried.Parent = root
			local buriedBefore = (buried:FindFirstChild("Trunk") :: Part).Position.Y

			local moved = Planter.reseat(root, flat)
			expect(moved).to.equal(1)
			local gap = Planter.junctionGap(floating, flat)
			TestKit.note(string.format("reseat: floater was +40, now %.3f", gap or -999))
			expect((gap :: number) <= TreeGround.TOLERANCE_STUDS).to.equal(true)
			expect((gap :: number) < 0).to.equal(true)
			-- THE BURIED ONE IS NOT RAISED: `decide` only ever sinks, and raising saved content is a
			-- question nobody has asked.
			expect((buried:FindFirstChild("Trunk") :: Part).Position.Y).to.equal(buriedBefore)

			root:Destroy()
		end)

		it("allows a bigger step for a bigger tree, with the tool's number as the floor", function()
			-- `Places.stepAllowance` IS NEW IN THIS TASK and nothing asserted either branch (Reviewer,
			-- round 1, finding 2). `TreeGround.CLIFF_STUDS` is the RE-SEATING tool's number -- *"would
			-- sinking this existing tree bury it?"* -- and a flat 4 refused 29% of candidates on this
			-- world's rolling ground. The junction still goes to the lowest sample either way, so what the
			-- allowance buys is buried uphill flare, and a tenth of the height is not visible.
			expect(Planter.stepAllowance(10)).to.equal(TreeGround.CLIFF_STUDS)
			expect(Planter.stepAllowance(0)).to.equal(TreeGround.CLIFF_STUDS)
			expect(Planter.stepAllowance(100)).to.equal(10)
			expect(Planter.stepAllowance(85)).to.equal(8.5)
			-- THE FLOOR AND THE FRACTION CROSS AT TEN TIMES `CLIFF_STUDS`, so nothing shorter than that
			-- is ever given less than the tool's own allowance.
			expect(Planter.stepAllowance(TreeGround.CLIFF_STUDS * 10)).to.equal(TreeGround.CLIFF_STUDS)
		end)

		it("is in the ground reader's ignore list, so our own trees are not the ground", function()
			-- DESIGN 10.1. `ForestTest.groundAt` is the CANOPY half of `Markers.groundFor`, where a
			-- one-stud disagreement with the terrain reader refuses a stand -- and a planted trunk is a
			-- legal ray hit because it keeps `CanQuery = true`. The folder name exists once, here.
			expect(table.find(Forest.GROUND_IGNORE, Planter.FOLDER) ~= nil).to.equal(true)
			expect(Planter.FOLDER).to.equal("DrivePlaces")
		end)

		it("plants nothing when nobody hands it a ground reader", function()
			-- THERE IS NO DEFAULT READER (design 10.1): the boot passes `ForestTest.terrainYAt`, and a
			-- caller who forgets gets a report with a reason rather than a forest measured against its
			-- own trunks.
			local empty = Instance.new("Folder")
			local report = Planter.build(nil, empty)
			expect(report.reason).to.equal("no-ground-reader")
			expect(report.planted).to.equal(0)
			expect(empty:FindFirstChild(Planter.FOLDER)).to.equal(nil)
			empty:Destroy()
		end)

		it("paints the ground each reference frame shows, per place", function()
			-- THE DIRECTOR'S LOOK, 2026-10-17: place 3 *"the hunter stands on GREY ASPHALT-LOOKING
			-- ground"*, place 4 *"grey ground again"*, place 1 *"shows grass and an oak and NO ROAD"*.
			-- Measured: the cut line's strip is 13 of 42 samples Asphalt, the forest road's 23 of 42, and
			-- place 1's own line is 29 of 65 **Grass** with the grass at five of its nine stands.
			--
			-- THE TERRAIN IS A FAKE WITH A RECORDING `ReplaceMaterial`, which is `Lobby.Field`'s own
			-- discipline: no spec in the DEV place can ever write DEV's terrain.
			local calls = {}
			local fake = {
				ReplaceMaterial = function(_self, region, resolution, source, target)
					table.insert(calls, { region = region, resolution = resolution, source = source, target = target })
				end,
			}
			local function flat(_x, _z)
				return 150
			end
			-- WHAT EACH PLACE'S GROUND IS, as the one table a reader can check against her frames.
			local want = {
				road = Enum.Material.Ground, -- karen-ref-7, a pale gravel road; 31/65 of it already was
				edge = nil, -- karen-ref-6 is a grass field; `Ground` there would be a ploughed field
				ride = Enum.Material.Grass, -- karen-ref-5 is a GRASSY ride with two earth ruts
				track = Enum.Material.Ground, -- karen-ref-1 is a brown dirt track under leaves
			}
			local painted, bare = 0, 0
			for _, name in ipairs(Forest.LAYOUT_ORDER) do
				local layout = Forest.layoutNamed(name)
				local surface = Plan.surfaceFor(name)
				table.clear(calls)
				local n = Ground.paint(fake, layout, surface, function(x)
					return Forest.roadZ(x, layout)
				end, flat)
				expect(n).to.equal(#calls)
				if want[name] == nil then
					bare += 1
					expect(surface).to.equal(nil)
					expect(n).to.equal(0)
				else
					painted += 1
					expect(surface).never.to.equal(nil)
					expect(surface.material).to.equal(want[name])
					expect(n > 0).to.equal(true)
					-- THE GREYS ARE IN THE SOURCE LIST, which is the whole of the Director's fix: a paint
					-- that skips Asphalt skips exactly the patches he objected to.
					local sources = {}
					for _, call in ipairs(calls) do
						sources[call.source] = true
						expect(call.resolution).to.equal(Ground.RESOLUTION)
						-- A BAND NEVER REPLACES A MATERIAL WITH ITSELF.
						expect(call.source).never.to.equal(call.target)
						-- THE REGION IS ON THE 4-STUD GRID. Task 191 measured "623 Ground and 2 Grass" over
						-- a rectangle that should have been uniform, because its edge was not.
						local min = call.region.CFrame.Position - call.region.Size / 2
						expect(math.abs(min.X % Ground.RESOLUTION) < 0.001).to.equal(true)
						expect(math.abs(min.Z % Ground.RESOLUTION) < 0.001).to.equal(true)
					end
					expect(sources[Enum.Material.Asphalt]).to.equal(true)
					expect(sources[Enum.Material.Grass] or want[name] == Enum.Material.Grass).to.equal(true)
				end
			end
			expect(painted).to.equal(3)
			expect(bare).to.equal(1)
			TestKit.note(
				string.format(
					"ground: road=%s ride=%s track=%s edge=(left as the world made it)",
					tostring(want.road),
					tostring(want.ride),
					tostring(want.track)
				)
			)
		end)

		it("paints a band the line never leaves, on the one place that curves", function()
			-- THE DEFECT THIS CASE EXISTS FOR (Reviewer, round 1 after the PASS, finding 1): `paint` takes
			-- ONE z per chunk, and at the 200 studs that shipped, place 1's sine (amplitude 30, wavelength
			-- 440) left its own band by up to the full amplitude -- the chunk [2630, 2830] was painted at
			-- z -2080.7..-2058.7 while the road's z at x 2830 is -2105.4, 21 studs outside. Stands 2 and 8,
			-- two of the five the Director measured as grass, stayed grass.
			--
			-- IT SAMPLES THE LINE AND ASKS WHETHER ANY PAINTED REGION HOLDS IT, which the material case
			-- cannot: that one checks material, resolution and grid alignment, all of which were right.
			for _, name in ipairs(Forest.LAYOUT_ORDER) do
				local surface = Plan.surfaceFor(name)
				local layout = Forest.layoutNamed(name)
				if surface ~= nil and layout ~= nil then
					local regions = {}
					local fake = {
						ReplaceMaterial = function(_self, region, _resolution, _source, target)
							if target == surface.material then
								table.insert(regions, region)
							end
						end,
					}
					Ground.paint(fake, layout, surface, function(x)
						return Forest.roadZ(x, layout)
					end, function()
						return 150
					end)
					expect(#regions > 0).to.equal(true)
					local from = layout.centre.X - surface.plotHalfWidthStuds
					local to = layout.centre.X + surface.plotHalfWidthStuds
					local worst, worstAt = -math.huge, 0
					for x = from, to, 5 do
						local z = Forest.roadZ(x, layout)
						local inside = false
						for _, region in ipairs(regions) do
							local at = region.CFrame.Position
							local half = region.Size / 2
							if
								x >= at.X - half.X - 0.001
								and x <= at.X + half.X + 0.001
								and z >= at.Z - half.Z - 0.001
								and z <= at.Z + half.Z + 0.001
							then
								inside = true
								break
							end
						end
						if not inside and x > worst then
							worst, worstAt = x, x
						end
						expect(inside).to.equal(true)
					end
					local _ = worstAt
					-- ...AND EVERY STAND IS ON IT, which is the Director's actual complaint: a hunter on
					-- stand 2 or 8 of place 1 was standing in grass.
					for index = 1, layout.standCount do
						local stand = Forest.standPosition(index, layout)
						local inside = false
						for _, region in ipairs(regions) do
							local at = region.CFrame.Position
							local half = region.Size / 2
							if
								stand.X >= at.X - half.X - 0.001
								and stand.X <= at.X + half.X + 0.001
								and stand.Z >= at.Z - half.Z - 0.001
								and stand.Z <= at.Z + half.Z + 0.001
							then
								inside = true
								break
							end
						end
						expect(inside).to.equal(true)
					end
					TestKit.note(
						string.format(
							"%s: %d region(s), chunk %d studs, every sample and all %d stands on the paint",
							name,
							#regions,
							Ground.chunkFor(layout, surface),
							layout.standCount
						)
					)
				end
			end
		end)

		it("paints a band exactly as wide as it was asked for, whatever the line's parity", function()
			-- `ExpandToGrid` ROUNDS OUTWARD (Reviewer, round 1 after the PASS, finding 2): the ride's ruts,
			-- asked for at 4 studs, were painted **8**, because its line z is a multiple of 4 and the
			-- nominal edges straddled a column. The forest road's came out at 4 only because its z happens
			-- to be 2 off the grid. A rut's width must not depend on where the line was put.
			for _, centre in ipairs({ -4540, -4528, -3894, -3900, 0, 2, 7.5, -1.25 }) do
				local low, high = Ground.bandBounds(centre, 2)
				expect(high - low).to.equal(4)
				expect(math.abs(low % Ground.RESOLUTION) < 0.001).to.equal(true)
				expect(centre >= low and centre <= high).to.equal(true)
				-- a 32-stud half-width is 64 studs, always
				local wideLow, wideHigh = Ground.bandBounds(centre, 32)
				expect(wideHigh - wideLow).to.equal(64)
			end
			-- ...and the width is `ceil(2 * half / RESOLUTION)` columns, so an odd half still gets whole
			-- voxels rather than a fraction of one.
			local low, high = Ground.bandBounds(-2097, 11)
			expect(high - low).to.equal(24)
		end)

		it("lays two wheel ruts over the strip, and only where a frame shows them", function()
			-- karen-ref-5 and karen-ref-1 both show TWO darker lines with something growing between them,
			-- not one bare track. The ruts are strips of MATERIAL and not trenches: a terrain voxel is 4
			-- studs (1.1 m) and a rut is a hand deep, so cutting one is not reachable.
			for _, name in ipairs({ "ride", "track" }) do
				local surface = Plan.surfaceFor(name)
				expect(surface.ruts).never.to.equal(nil)
				-- A RUT MUST FIT INSIDE THE STRIP IT IS IN, or it is a stripe across the verge.
				expect(surface.ruts.offsetStuds + surface.ruts.halfWidthStuds <= surface.halfWidthStuds).to.equal(true)
				expect(surface.ruts.material).never.to.equal(surface.material)
			end
			-- ...and the road has none: karen-ref-7 is a graded gravel road, not a pair of ruts.
			expect(Plan.surfaceFor("road").ruts).to.equal(nil)

			-- THE RUTS ARE PAINTED AFTER THE STRIP, which is load-bearing now that the strip's own
			-- material is in `SOURCE_MATERIALS`: the other order paints them straight back over.
			local order = {}
			local fake = {
				ReplaceMaterial = function(_self, _region, _resolution, _source, target)
					table.insert(order, target)
				end,
			}
			local layout = Forest.layoutNamed("ride")
			local surface = Plan.surfaceFor("ride")
			Ground.paint(fake, layout, surface, function(x)
				return Forest.roadZ(x, layout)
			end, function()
				return 150
			end)
			local firstRut, lastStrip = nil, nil
			for index, target in ipairs(order) do
				if target == surface.ruts.material and firstRut == nil then
					firstRut = index
				end
				if target == surface.material then
					lastStrip = index
				end
			end
			expect(firstRut).to.be.ok()
			expect(lastStrip).to.be.ok()
			-- within the FIRST chunk the strip is laid before its ruts
			expect(firstRut > 1).to.equal(true)
		end)

		it("measures the painted band off the ground and not off centre.Y", function()
			-- `centre.Y` IS A FALLBACK GROUND (task 179's design 3.4) and this ground rolls 29-37 studs
			-- along a stand line, so a band taken from it would miss the strip at one end.
			local layout = Forest.layoutNamed("track")
			local low, high = Ground.yBandOf(layout, Plan.surfaceFor("track"), function(x)
				return Forest.roadZ(x, layout)
			end, function(x, _z)
				return 100 + (x - layout.centre.X) * 0.05
			end)
			expect(low).to.be.ok()
			expect(high).to.be.ok()
			-- the fake slopes 0.05 per stud over +-410 studs, i.e. 79.5..120.5, padded both ways
			expect(low <= 79.5 - Ground.Y_PAD_STUDS + 0.001).to.equal(true)
			expect(high >= 120.5 + Ground.Y_PAD_STUDS - 0.001).to.equal(true)
			-- A PLACE WITH NO SURFACE HAS NO BAND, rather than a band nobody paints.
			local none = Ground.yBandOf(Forest.layoutNamed("edge"), Plan.surfaceFor("edge"), function(x)
				return Forest.roadZ(x, Forest.layoutNamed("edge"))
			end, function()
				return 150
			end)
			expect(none).to.equal(nil)
		end)

		it("plants nothing at all when the templates are not in this place", function()
			-- THE DEV CASE. Neither `OurForest` nor `Session` exists there, and the answer is a
			-- report with a reason -- not a crash, and not a folder.
			local empty = Instance.new("Folder")
			expect(#Planter.templates(empty)).to.equal(0)
			local report = Planter.build(function()
				return 100
			end, empty, nil)
			expect(report.reason).to.equal("no-templates")
			expect(report.planted).to.equal(0)
			expect(empty:FindFirstChild(Planter.FOLDER)).to.equal(nil)
			empty:Destroy()
		end)
	end)
end
