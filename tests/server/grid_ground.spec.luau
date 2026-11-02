--!nocheck
-- Task 328b: DO THE TREES SIT RIGHT? The contact rule's identity, the template audit and the
-- quarantine, and `ServerStorage.GridCensus` -- design 13.2's cases 1, 2, 3, 10, 11 and 12, plus the
-- two this task's own code needs (the Atomic streaming pair, and the crown rule by parameter).
--
-- CASES 4 TO 9 ARE TASK 328f's and are here now: `Places.mask` and `Places.REASON` in their stated
-- order, the 34 / 27-stud floors measured INDEPENDENTLY of the mask, the linear crown term by
-- parameter, the frontage rule over all eight cells, the ferns clear of the ditch and the verge, and
-- `Places.standTypeFor` derived.
--
-- EVERYTHING RUNS WITH NO WORLD AND NO TERRAIN: every ground reading is a FAKE HILLSIDE handed in as
-- a function, and every template is built here out of Parts. That is `grid.spec`'s own discipline.
--
-- Design: docs/design/grid-terrain.md sections 9.1-9.4, 13.2
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	local ServerStorage = game:GetService("ServerStorage")
	local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
	local TreeGround = require(ReplicatedStorage:WaitForChild("TreeGround"))
	local Plan = require(ReplicatedStorage:WaitForChild("Places"))
	local Grid = require(ReplicatedStorage:WaitForChild("Grid"))
	local Forest = require(ReplicatedStorage:WaitForChild("ForestTest"))
	local Planter = require(ServerScriptService:WaitForChild("Places"))
	local Census = require(ServerStorage:WaitForChild("GridCensus"))

	-- A FLAT WORLD AT A KNOWN HEIGHT, and a hillside that rises 0.1 studs a stud in x.
	local function flat(_x: number, _z: number): number?
		return 100
	end
	local function hillside(x: number, _z: number): number?
		return 100 + 0.1 * x
	end

	-- ONE SYNTHETIC TEMPLATE: a trunk and a crown, named the way this world's artists name them, so
	-- `Plan.isFoliageName` splits them the way it splits a real birch.
	local function template(name: string, trunkSize: Vector3, crownSize: Vector3?): Model
		local model = Instance.new("Model")
		model.Name = name
		local trunk = Instance.new("Part")
		trunk.Name = "Trunk"
		trunk.Size = trunkSize
		trunk.Anchored = true
		trunk.CFrame = CFrame.new(0, trunkSize.Y / 2, 0)
		trunk.Parent = model
		if crownSize ~= nil then
			local crown = Instance.new("Part")
			crown.Name = "SM_Leaves"
			crown.Size = crownSize
			crown.Anchored = true
			crown.CFrame = CFrame.new(0, trunkSize.Y, 0)
			crown.Parent = model
		end
		model.PrimaryPart = trunk
		return model
	end

	local function plantingAt(name: string, x: number, z: number): any
		return { model = name, x = x, z = z, scale = 1, yaw = 0, band = "wood", side = 1 }
	end

	-- ---------------------------------------------------------------- 1. the contact rule

	describe("the contact rule is TreeGround's, by identity", function()
		it("the planter, the plan and the census read ONE allowance, ONE sink and ONE tolerance", function()
			-- THE ALLOWANCE IS THE SAME FUNCTION and not the same formula typed twice: the server's
			-- `stepAllowance` IS `Plan.stepAllowanceStuds` since task 328b.
			expect(Planter.stepAllowance).to.equal(Plan.stepAllowanceStuds)
			-- THE CONSTANTS, not the formula: transcribing the function under test can only catch a
			-- deleted one (verdict 278). `places.spec` pins the shipped values (70 -> 7, 100 -> 10).
			expect(TreeGround.CLIFF_STUDS).to.equal(4)
			expect(Plan.stepAllowanceStuds(2.8)).to.equal(TreeGround.CLIFF_STUDS)
			-- THE CENSUS DEFINES NEITHER. It has no tolerance and no sink of its own, so there is
			-- nothing for a fork to drift from.
			expect(rawget(Census, "TOLERANCE_STUDS")).to.equal(nil)
			expect(rawget(Census, "SINK_STUDS")).to.equal(nil)
			expect(rawget(Census, "sinkFor")).to.equal(nil)
			expect(TreeGround.TOLERANCE_STUDS).to.equal(0.2)
			expect(TreeGround.sinkFor(60)).to.equal(0.6)
			-- ...AND THE ONE IT DOES OWN IS THE LEAN, which is design 9.4's own 2 degrees.
			expect(math.abs(Census.TILT_COS - math.cos(math.rad(2))) < 1e-9).to.equal(true)
			-- THE LYING RULE IS THE AUDIT'S 5 DEGREES, in the shared module, read by both.
			expect(Plan.AUDIT_LYING_DEGREES).to.equal(5)
		end)
	end)

	-- ---------------------------------------------------------------- 2. TEMPLATE_DIMS and the quarantine

	describe("TEMPLATE_DIMS covers exactly the names Places.SPECIES plants", function()
		it("is 35 of 35, with no extras, and every row is a measurement", function()
			local planted: { [string]: boolean } = {}
			local count = 0
			for _, names in pairs(Plan.SPECIES) do
				for _, name in ipairs(names) do
					planted[name] = true
					count += 1
				end
			end
			expect(count).to.equal(35)
			local rows = 0
			for name, row in pairs(Plan.TEMPLATE_DIMS) do
				rows += 1
				expect(planted[name]).to.equal(true)
				-- A ROW IS A MEASUREMENT: a real scale, a real height, a trunk, and a part count.
				expect(row.scale > 0).to.equal(true)
				expect(row.heightStuds > 0).to.equal(true)
				expect(row.trunkHalfWidthStuds > 0).to.equal(true)
				expect(row.crownHalfWidthStuds >= 0).to.equal(true)
				expect(row.parts >= 1).to.equal(true)
				expect(Plan.dimsFor(name)).to.equal(row)
			end
			expect(rows).to.equal(35)
			TestKit.note(string.format(
				"TEMPLATE_DIMS: %d rows, %d quarantined",
				rows,
				(function()
					local n = 0
					for _ in pairs(Plan.QUARANTINE) do
						n += 1
					end
					return n
				end)()
			))
			for name in pairs(planted) do
				expect(Plan.dimsFor(name) ~= nil).to.equal(true)
			end
		end)

		it("every QUARANTINE name is in SPECIES, and is never planted by any caller", function()
			local groups = {}
			for group in pairs(Plan.SPECIES) do
				table.insert(groups, group)
			end
			for name in pairs(Plan.QUARANTINE) do
				expect(Plan.isQuarantined(name)).to.equal(true)
				expect(Plan.dimsFor(name) ~= nil).to.equal(true)
			end
			-- `namesOf` IS THE ONE DOOR, so the check is on it and on the list it feeds.
			for _, group in ipairs(groups) do
				local names = Plan.namesOf(group)
				for _, name in ipairs(names) do
					expect(Plan.isQuarantined(name)).to.equal(false)
				end
				-- NOTHING IS QUARANTINED TODAY, so the door is the identity -- asserted rather than
				-- assumed, because that is what makes the planting list bit-identical to task 327c's.
				local source = (Plan.SPECIES :: any)[group]
				expect(#names).to.equal(#source)
				for index, name in ipairs(source) do
					expect(names[index]).to.equal(name)
				end
			end
			for _, id in ipairs({ "C1", "A1", "D2" }) do
				for _, item in ipairs(Plan.plantCell(id)) do
					expect(Plan.isQuarantined(item.model)).to.equal(false)
				end
			end
		end)

		it("the herb groups are the ferns, and nothing else is exempt from the axis rule", function()
			expect(Plan.HERB_GROUPS.fern).to.equal(true)
			for _, name in ipairs(Plan.SPECIES.fern) do
				expect(Plan.isHerbName(name)).to.equal(true)
				-- MEASURED 2026-11-02: every fern template is wider than it is tall.
				local row = Plan.dimsFor(name)
				expect(row.heightStuds < row.trunkHalfWidthStuds * 2).to.equal(true)
			end
			for _, name in ipairs(Plan.SPECIES.birch) do
				expect(Plan.isHerbName(name)).to.equal(false)
			end
		end)
	end)

	-- ---------------------------------------------------------------- 3. the audit catches each failure

	describe("the template audit catches each failure separately", function()
		local function measuredOf(model: Model): any
			return Planter.measureFor(model)
		end

		it("passes a sound template, and names a lying trunk, a detached crown, a part count and extents", function()
			local good = template("GoodTree", Vector3.new(2, 40, 2), Vector3.new(16, 10, 16))
			local dims = { scale = 1, heightStuds = 45, trunkHalfWidthStuds = 1, crownHalfWidthStuds = 8, parts = 2 }
			expect(Plan.auditReason(measuredOf(good), dims, 1)).to.equal(nil)

			-- A LYING TRUNK: laid over by 80 degrees, so its box's longest extent is no longer Y.
			local lying = template("LyingTree", Vector3.new(2, 40, 2), Vector3.new(16, 10, 16))
			local trunk = lying:FindFirstChild("Trunk") :: BasePart
			trunk.CFrame = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(80))
			expect(Plan.auditReason(measuredOf(lying), dims, 1)).to.equal("trunk-axis-not-Y")

			-- ...AND ONE THAT IS ONLY LEANING, 7 degrees: still tallest in Y, so the AXIS arm lets it
			-- through and the LYING arm is what catches it.
			local leaning = template("LeaningTree", Vector3.new(2, 40, 2), Vector3.new(16, 10, 16))
			local leaningTrunk = leaning:FindFirstChild("Trunk") :: BasePart
			leaningTrunk.CFrame = CFrame.new(0, 20, 0) * CFrame.Angles(0, 0, math.rad(7))
			expect(Plan.auditReason(measuredOf(leaning), nil, 1)).to.equal("trunk-lying")

			-- A DETACHED CROWN: lifted clear of the trunk's top.
			local floatingCrown = template("DetachedTree", Vector3.new(2, 40, 2), Vector3.new(16, 10, 16))
			local crown = floatingCrown:FindFirstChild("SM_Leaves") :: BasePart
			crown.CFrame = CFrame.new(0, 60, 0)
			expect(Plan.auditReason(measuredOf(floatingCrown), dims, 1)).to.equal("foliage-detached")

			-- A CROWN THAT HAS SLID SIDEWAYS: no overlap in X with the trunk.
			local besideIt = template("AsideTree", Vector3.new(2, 40, 2), Vector3.new(16, 10, 16))
			local aside = besideIt:FindFirstChild("SM_Leaves") :: BasePart
			aside.CFrame = CFrame.new(40, 40, 0)
			expect(Plan.auditReason(measuredOf(besideIt), dims, 1)).to.equal("foliage-detached")

			-- A PART COUNT THAT DOES NOT MATCH THE ROW.
			local threeParts = template("ThreeTree", Vector3.new(2, 40, 2), Vector3.new(16, 10, 16))
			local extra = Instance.new("Part")
			extra.Name = "Trunk2"
			extra.Size = Vector3.new(1, 1, 1)
			extra.CFrame = CFrame.new(0, 20, 0)
			extra.Parent = threeParts
			expect(Plan.auditReason(measuredOf(threeParts), dims, 1)).to.equal("part-count")
		end)

		it("the extents arm divides by TEMPLATE_DIMS.scale and NOT by 1 (design 9.2)", function()
			-- THE REFERENCE WAS MEASURED AT 0.5 AND THE MODEL STANDS AT 0.5: the same tree.
			local model = template("ScaledTree", Vector3.new(2, 40, 2), Vector3.new(16, 10, 16))
			local tall = { scale = 0.5, heightStuds = 45, trunkHalfWidthStuds = 1, crownHalfWidthStuds = 8, parts = 2 }
			expect(Plan.auditReason(Planter.measureFor(model), tall, 0.5)).to.equal(nil)
			-- ...AND AT SCALE 1 THE SAME MODEL IS TWICE THE REFERENCE, which is the failure a
			-- "measured at scale 1" reference would have produced on 30 of this world's 35 templates.
			expect(Plan.auditReason(Planter.measureFor(model), tall, 1)).to.equal("extents")
			-- A 10% DIFFERENCE IS INSIDE THE BAND, a 20% one is outside it.
			local near = { scale = 1, heightStuds = 50, trunkHalfWidthStuds = 1, crownHalfWidthStuds = 8, parts = 2 }
			expect(Plan.auditReason(Planter.measureFor(model), near, 1)).to.equal(nil)
			local far = { scale = 1, heightStuds = 57, trunkHalfWidthStuds = 1, crownHalfWidthStuds = 8, parts = 2 }
			expect(Plan.auditReason(Planter.measureFor(model), far, 1)).to.equal("extents")
		end)

		it("a QUARANTINED name is refused by the audit, dropped by namesOf, and never planted", function()
			-- THE QUARANTINE IS EMPTY TODAY -- all 35 templates pass -- so the door has to be driven to
			-- be proved (round 1, finding 1). `isQuarantined` is stubbed for one name and the memo
			-- forgotten; everything else is the shipped code.
			-- THE VICTIM IS A FERN, so the fixture can be a template that genuinely PASSES its own
			-- measured row: `SM_Forest_Fern_Var01` is one part, 2.2 studs tall, at scale 1.
			local victim = "SM_Forest_Fern_Var01"
			local group = "fern"
			local real = Plan.isQuarantined
			local function restore()
				Plan.isQuarantined = real
				Plan.forgetPlantable()
			end
			local function fern(): Model
				local made = Instance.new("Model")
				made.Name = victim
				local part = Instance.new("Part")
				part.Name = "Trunk"
				part.Size = Vector3.new(9.6, 2.2, 9.6)
				part.Anchored = true
				part.CFrame = CFrame.new(0, 1.1, 0)
				part.Parent = made
				made.PrimaryPart = part
				return made
			end
			local model = fern()
			-- BEFORE: it is a sound template -- it passes its OWN measured row -- and is planted.
			expect(Planter.auditTemplate(model, victim)).to.equal(nil)
			local beforeNames = Plan.namesOf(group)
			expect(table.find(beforeNames, victim) ~= nil).to.equal(true)
			local function buildWith(make: (() -> Model)?): any
				local world = Instance.new("Folder")
				local forest = Instance.new("Folder")
				forest.Name = "OurForest"
				local source = if make ~= nil then make() else fern()
				source.Parent = forest
				forest.Parent = world
				local report = Planter.build(function()
					return 120
				end, world, { ReplaceMaterial = function() end }, false)
				local drawn = 0
				local folder = world:FindFirstChild(Planter.FOLDER)
				if folder ~= nil then
					for _, place in ipairs(folder:GetChildren()) do
						for _, child in ipairs(place:GetChildren()) do
							if child.Name == victim then
								drawn += 1
							end
						end
					end
				end
				world:Destroy()
				return { report = report, drawn = drawn }
			end
			local sound = buildWith()
			expect(sound.drawn > 0).to.equal(true)
			expect(sound.report.quarantined).to.equal(0)

			-- AFTER: the same name, quarantined. Three doors, each asserted on its own.
			local ok, err = pcall(function()
				Plan.isQuarantined = function(name: string): boolean
					return name == victim
				end
				Plan.forgetPlantable()
				-- (a) the audit refuses it, by name, before it measures anything.
				expect(Planter.auditTemplate(model, victim)).to.equal("quarantined")
				-- (b) `namesOf` drops it, and drops only it.
				local after = Plan.namesOf(group)
				expect(#after).to.equal(#beforeNames - 1)
				expect(table.find(after, victim)).to.equal(nil)
				for _, name in ipairs(beforeNames) do
					if name ~= victim then
						expect(table.find(after, name) ~= nil).to.equal(true)
					end
				end
				-- ...so no planting list names it, in any cell.
				for _, id in ipairs({ "C1", "A1" }) do
					for _, item in ipairs(Plan.plantCell(id)) do
						expect(item.model).never.to.equal(victim)
					end
				end
				-- (c) ...so `Places.build` plants NONE of it, and `report.quarantined` stays 0:
				-- the LIST door shut first and the planter never asked for the template at all.
				-- That is the stronger of the two statements, and the build's own audit arm is
				-- driven by the broken-template case below.
				local refused = buildWith()
				expect(refused.drawn).to.equal(0)
				expect(refused.report.quarantined).to.equal(0)
			end)
			restore()
			if not ok then
				error(err, 0)
			end
			-- AND THE DOOR OPENS AGAIN, so the stub is proved to have been the only thing holding it.
			expect(Planter.auditTemplate(model, victim)).to.equal(nil)
			expect(table.find(Plan.namesOf(group), victim) ~= nil).to.equal(true)
			model:Destroy()
		end)

		it("build refuses a template that has DRIFTED from its row, and plants none of it", function()
			-- THE OTHER HALF OF THE QUARANTINE: a name nobody quarantined whose TEMPLATE no longer
			-- matches `TEMPLATE_DIMS`. The list still carries it, so `Places.build`'s own audit
			-- closure is what must refuse it -- `refusedTemplates`, `report.quarantined` and
			-- `report.quarantinedBy` (round 1, finding 1).
			local victim = "SM_Forest_Fern_Var01"
			local function fernWith(parts: number): Model
				local made = Instance.new("Model")
				made.Name = victim
				for index = 1, parts do
					local part = Instance.new("Part")
					part.Name = "Trunk" .. tostring(index)
					part.Size = Vector3.new(9.6, 2.2, 9.6)
					part.Anchored = true
					part.CFrame = CFrame.new(0, 1.1, 0)
					part.Parent = made
					if index == 1 then
						made.PrimaryPart = part
					end
				end
				return made
			end
			local function buildWith(make: () -> Model): any
				local world = Instance.new("Folder")
				local forest = Instance.new("Folder")
				forest.Name = "OurForest"
				local source = make()
				source.Parent = forest
				forest.Parent = world
				local report = Planter.build(function()
					return 120
				end, world, { ReplaceMaterial = function() end }, false)
				local drawn = 0
				local folder = world:FindFirstChild(Planter.FOLDER)
				if folder ~= nil then
					for _, place in ipairs(folder:GetChildren()) do
						for _, child in ipairs(place:GetChildren()) do
							if child.Name == victim then
								drawn += 1
							end
						end
					end
				end
				world:Destroy()
				return { report = report, drawn = drawn }
			end
			local sound = buildWith(function()
				return fernWith(1)
			end)
			expect(sound.drawn > 0).to.equal(true)
			expect(sound.report.quarantined).to.equal(0)
			local drifted = buildWith(function()
				return fernWith(2)
			end)
			expect(drifted.drawn).to.equal(0)
			expect(drifted.report.quarantined).to.equal(1)
			expect(drifted.report.quarantinedBy["part-count"]).to.equal(1)
			TestKit.note(string.format("quarantine: a drifted template planted %d of %d", drifted.drawn, sound.drawn))
		end)

		it("a real template passes its own measured row", function()
			local good = template("GoodTree", Vector3.new(2, 40, 2), Vector3.new(16, 10, 16))
			expect(Planter.auditTemplate(good, "GoodTree")).to.equal(nil)
			expect(Plan.dimsFor("SilverBirch_Var11_LOD_0") ~= nil).to.equal(true)
			good:Destroy()
		end)
	end)

	-- ---------------------------------------------------------------- 10/11. the census

	-- ------------------------------------------------- 4-9. the forest v2 (task 328f, design 13.2)

	-- THE ROADS AND THE RIDES, MEASURED HERE AND NOT THROUGH THE MASK. `drive-places.md` section
	-- 10.4 item 3's lesson: a rule checked with the function that enforces it proves only that the
	-- function agrees with itself.
	local function roadGap(x: number, z: number): number
		local best = math.huge
		for _, road in ipairs(Grid.roads()) do
			if road.axis == "x" then
				if x >= road.from and x <= road.to then
					best = math.min(best, math.abs(z - road.at))
				end
			elseif z >= road.from and z <= road.to then
				best = math.min(best, math.abs(x - road.at))
			end
		end
		return best
	end
	local function rideGap(cellId: string, x: number, z: number): number
		local best = math.huge
		for _, seg in ipairs(Plan.rideSegments(cellId)) do
			local dx, dz = seg.bx - seg.ax, seg.bz - seg.az
			local len2 = dx * dx + dz * dz
			local t = if len2 <= 0 then 0 else math.clamp(((x - seg.ax) * dx + (z - seg.az) * dz) / len2, 0, 1)
			local px, pz = seg.ax + t * dx, seg.az + t * dz
			best = math.min(best, math.sqrt((x - px) * (x - px) + (z - pz) * (z - pz)))
		end
		return best
	end

	describe("the mask refuses for the right reason, in the stated order", function()
		it("every reason is in REASON_ORDER once, and the two a pure mask cannot reach are named", function()
			local order = Plan.REASON_ORDER
			local seen = {}
			for _, reason in ipairs(order) do
				expect(seen[reason]).to.equal(nil)
				seen[reason] = true
			end
			local count = 0
			for _, reason in pairs(Plan.REASON) do
				count += 1
				expect(seen[reason]).to.equal(true)
			end
			expect(#order).to.equal(count)
			expect(#order).to.equal(15)
			-- THE ORDER IS A TABLE AND NOT PROSE (design 8.2): outermost fact first.
			expect(order[1]).to.equal(Plan.REASON.ROAD)
			expect(order[2]).to.equal(Plan.REASON.DITCH)
			expect(order[3]).to.equal(Plan.REASON.VERGE)
			expect(order[4]).to.equal(Plan.REASON.RIDE)
			expect(order[#order]).to.equal(Plan.REASON.GAP)
			expect(#Plan.REASON_NOT_MASKED).to.equal(2)
		end)

		it("names the band a point is actually in, and the two unreachable reasons never come back", function()
			local cellId = "C1"
			local road = Grid.roadsOf(cellId).main
			local box = Grid.boundsOf(cellId)
			local x = (box.minX + box.maxX) / 2
			-- INTO THE CELL from the main road's centre line, one band at a time.
			local function at(distance: number): string?
				return Plan.mask(cellId, x, road.at + distance, nil, nil)
			end
			expect(at(0)).to.equal(Plan.REASON.ROAD)
			expect(at(21)).to.equal(Plan.REASON.ROAD)
			expect(at(25)).to.equal(Plan.REASON.DITCH)
			expect(at(32)).to.equal(Plan.REASON.VERGE)
			-- ...AND NOT ROAD, DITCH OR VERGE past 34.
			local past = at(40)
			expect(past ~= Plan.REASON.ROAD).to.equal(true)
			expect(past ~= Plan.REASON.DITCH).to.equal(true)
			expect(past ~= Plan.REASON.VERGE).to.equal(true)
			-- THE TWO THE PURE MASK CANNOT ANSWER, over a lattice of the whole cell.
			for step = 0, 40 do
				local px = box.minX + (box.maxX - box.minX) * step / 40
				for inner = 0, 40 do
					local pz = box.minZ + (box.maxZ - box.minZ) * inner / 40
					local why = Plan.mask(cellId, px, pz, "SilverBirch_Var08_LOD_0", 1)
					expect(why ~= Plan.REASON.CLIFF).to.equal(true)
					expect(why ~= Plan.REASON.GAP).to.equal(true)
				end
			end
		end)
	end)

	describe("no trunk stands in a road or a ride", function()
		it("every planting of every cell clears 34 studs of road and 27 of ride, measured here", function()
			for _, id in ipairs(Grid.cellIds()) do
				local worstRoad, worstRide = math.huge, math.huge
				local trees = 0
				for _, item in ipairs(Plan.plantCell(id)) do
					local herb = Plan.isHerbName(item.model)
					worstRoad = math.min(worstRoad, roadGap(item.x, item.z))
					if not herb then
						trees += 1
						-- THE RIDE IS THE CELL'S OWN; a skirt planting is inside the NEIGHBOUR, and
						-- `plantCell` masks it against that cell, so ask both.
						for _, other in ipairs(Grid.cellIds()) do
							worstRide = math.min(worstRide, rideGap(other, item.x, item.z))
						end
					end
				end
				expect(trees > 0).to.equal(true)
				assert(
					worstRoad >= Plan.ROAD_TRUNK_FLOOR_STUDS,
					string.format("%s: a trunk stands %.2f st from a road centre", id, worstRoad)
				)
				assert(
					worstRide >= Plan.RIDE_TRUNK_FLOOR_STUDS,
					string.format("%s: a trunk stands %.2f st from a ride centre", id, worstRide)
				)
			end
		end)

		it("and the mask agrees with that independent measurement, point for point", function()
			local id = "C1"
			local box = Grid.boundsOf(id)
			local checked = 0
			for step = 0, 60 do
				local x = box.minX + (box.maxX - box.minX) * step / 60
				for inner = 0, 60 do
					local z = box.minZ + (box.maxZ - box.minZ) * inner / 60
					local why = Plan.mask(id, x, z, nil, nil)
					if roadGap(x, z) < Plan.ROAD_TRUNK_FLOOR_STUDS then
						expect(why ~= nil).to.equal(true)
					end
					if rideGap(id, x, z) <= Plan.RIDE_CLEAR_STUDS / 2 then
						expect(why ~= nil).to.equal(true)
					end
					checked += 1
				end
			end
			expect(checked).to.equal(61 * 61)
		end)
	end)

	describe("the crown rule is linear, by parameter", function()
		it("a measured crown raises the floor; a template with no row leaves it alone", function()
			-- THE WIDEST CROWN THIS WORLD HAS, from `TEMPLATE_DIMS` itself rather than a number
			-- typed here (lesson L-167).
			local widest, reach = nil, 0
			for name in pairs(Plan.SPECIES) do
				for _, each in ipairs(Plan.namesOf(name)) do
					local dims = Plan.dimsFor(each)
					if dims ~= nil and dims.crownHalfWidthStuds > reach then
						widest, reach = each, dims.crownHalfWidthStuds
					end
				end
			end
			expect(widest ~= nil).to.equal(true)
			local scale = 1.2
			-- **THE BASE IS THE CENSUS'S OWN HALF-WIDTH, NOT DESIGN 7.2's PAINTED 10** -- see the
			-- header of `Places.roadTrunkMin`. `GridCensus` counts a crown over a road inside
			-- `roadClearStuds / 2` plus the reach, so a set-back of `reach + 10` still counts.
			expect(Plan.roadTrunkMin(widest, scale)).to.be.near(
				math.max(
					Plan.ROAD_TRUNK_FLOOR_STUDS,
					Grid.CONFIG.roadClearStuds / 2 + reach * scale + Plan.CROWN_DRIFT_STUDS
				),
				1e-9
			)
			expect(Plan.rideTrunkMin(widest, scale)).to.be.near(
				math.max(
					Plan.RIDE_TRUNK_FLOOR_STUDS,
					Plan.RIDE_CLEAR_STUDS / 2 + reach * scale + Plan.CROWN_DRIFT_STUDS
				),
				1e-9
			)
			expect(Plan.roadTrunkMin(widest, scale) > Plan.ROAD_TRUNK_FLOOR_STUDS).to.equal(true)
			-- NO ROW: the floors are the whole rule (design 7.2), which is the census's
			-- `crownOverRoad=UNMEASURED`.
			expect(Plan.crownReachStuds("NoSuchTemplate", 1)).to.equal(nil)
			expect(Plan.roadTrunkMin("NoSuchTemplate", 1)).to.be.near(Plan.ROAD_TRUNK_FLOOR_STUDS, 1e-9)
			expect(Plan.rideTrunkMin("NoSuchTemplate", 1)).to.be.near(Plan.RIDE_TRUNK_FLOOR_STUDS, 1e-9)
		end)

		it("and the mask refuses a wide crown where it passes a narrow one, same point", function()
			local id = "C1"
			local box = Grid.boundsOf(id)
			local widest, reach = nil, 0
			for name in pairs(Plan.SPECIES) do
				for _, each in ipairs(Plan.namesOf(name)) do
					local dims = Plan.dimsFor(each)
					if dims ~= nil and dims.crownHalfWidthStuds > reach then
						widest, reach = each, dims.crownHalfWidthStuds
					end
				end
			end
			-- FIND THE POINT RATHER THAN TYPE IT: somewhere clear of every site rule, but inside the
			-- widest crown's own set-back. A hand-picked coordinate lands in a beater corridor or a
			-- front cone the first time a constant moves.
			local scale = 1.2
			local minimum = Plan.roadTrunkMin(widest, scale)
			local foundX, foundZ = nil, nil
			for step = 0, 200 do
				local x = box.minX + (box.maxX - box.minX) * step / 200
				for inner = 0, 200 do
					local z = box.minZ + (box.maxZ - box.minZ) * inner / 200
					local gap = roadGap(x, z)
					if
						gap >= Plan.ROAD_TRUNK_FLOOR_STUDS
						and gap < minimum
						and Plan.mask(id, x, z, nil, nil) == nil
					then
						foundX, foundZ = x, z
						break
					end
				end
				if foundX ~= nil then
					break
				end
			end
			assert(foundX ~= nil, "no point between the road floor and the crown set-back is otherwise plantable")
			-- THE WIDE CROWN IS REFUSED THERE...
			expect(Plan.mask(id, foundX, foundZ, widest, scale)).to.equal(Plan.REASON.CROWN)
			-- ...AND THE SAME POINT WITH NO TEMPLATE IS PLANTABLE: the crown term is this tree's own
			-- fact, which is what "by parameter" means.
			expect(Plan.mask(id, foundX, foundZ, nil, nil)).to.equal(nil)
			-- ...AND A FERN, WHICH HAS NO CROWN, STANDS THERE TOO.
			expect(Plan.mask(id, foundX, foundZ, "SM_Forest_Fern_Var05", 1)).to.equal(nil)
		end)
	end)

	describe("the frontage rule", function()
		it("draws only the named groups within 60 studs of a centreline, over all eight cells", function()
			local near, total = 0, 0
			for _, id in ipairs(Grid.cellIds()) do
				local plan = Plan.cellPlanFor(id)
				expect(plan.frontage ~= nil).to.equal(true)
				for _, item in ipairs(Plan.plantCell(id)) do
					total += 1
					if not Plan.isHerbName(item.model) then
						local inBand = roadGap(item.x, item.z) <= plan.frontage.studs
						for _, other in ipairs(Grid.cellIds()) do
							inBand = inBand or rideGap(other, item.x, item.z) <= plan.frontage.studs
						end
						if inBand then
							near += 1
							expect(Plan.frontageAllows(plan, item.model)).to.equal(true)
						end
					end
				end
			end
			expect(total > 0).to.equal(true)
			-- IT HAS TO BITE SOMEWHERE, or the case proves nothing (lesson L-086).
			expect(near > 0).to.equal(true)
		end)

		it("costs no density: every shipped mix keeps at least one allowed group", function()
			local plan = Plan.cellPlanFor("C1")
			for _, id in ipairs(Grid.cellIds()) do
				for _, zone in ipairs(Plan.cellPlanFor(id).zones) do
					local rows = Plan.cellMixNamed(zone.mix)
					if #rows > 0 then
						expect(#Plan.frontageRows(plan, rows) > 0).to.equal(true)
					end
				end
			end
			-- AND IT REALLY FILTERS: a spruce thicket's conifer row goes, its larch row stays.
			local thicket = Plan.frontageRows(plan, Plan.cellMixNamed("spruceThicket"))
			expect(#thicket).to.equal(1)
			expect(thicket[1].group).to.equal("young")
		end)
	end)

	describe("the ferns", function()
		it("stand clear of the ditch and the verge, and never more than the cap a cell", function()
			for _, id in ipairs(Grid.cellIds()) do
				local ferns = 0
				for _, item in ipairs(Plan.plantCell(id)) do
					if Plan.isHerbName(item.model) then
						ferns += 1
						-- DEFECT F-5: measured from the ROAD CENTRELINE, so 34 is the verge's far
						-- edge and no bracken stands in the 22-34 band design 7.1 keeps bare.
						expect(roadGap(item.x, item.z) >= Plan.VERGE_STUDS.to).to.equal(true)
					end
				end
				expect(ferns <= Plan.FERN_CAP).to.equal(true)
			end
			-- AND THE BAND ITSELF STARTS AT 34, not at the cell edge.
			local plan = Plan.cellPlanFor("C1")
			expect(plan.fernBand.fromStuds).to.equal(Plan.VERGE_STUDS.to)
			for _, rect in ipairs(Plan.fernBands("C1", plan)) do
				expect(roadGap(rect.minX, rect.minZ) >= Plan.VERGE_STUDS.to).to.equal(true)
			end
		end)
	end)

	describe("stand types are derived, never written", function()
		it("every stand of every cell gets one of the letters, and no recipe carries a letter", function()
			local allowed = {}
			for _, letter in ipairs(Plan.STAND_LETTERS) do
				allowed[letter] = true
			end
			for _, id in ipairs(Grid.cellIds()) do
				expect((Plan.cellPlanFor(id) :: any).standTypes).to.equal(nil)
				for index = 1, Grid.standCount(id) do
					expect(allowed[Plan.standTypeFor(id, index)]).to.equal(true)
				end
			end
		end)

		it("gives a v2 cell at least five distinct letters over its fifteen stands", function()
			-- EVERY CELL IN ONE MESSAGE, because a cell that fails has its RECIPE changed (design
			-- 8.5) and the person changing it needs the whole row, not the first one that broke.
			local report, worst, weakest = {}, 0, 99
			local v2Distinct, v2Adjacent = 99, 0
			for _, id in ipairs(Grid.cellIds()) do
				local seen, letters = {}, {}
				for index = 1, Grid.standCount(id) do
					local letter = Plan.standTypeFor(id, index)
					table.insert(letters, letter)
					seen[letter] = true
				end
				local distinct = 0
				for _ in pairs(seen) do
					distinct += 1
				end
				local adjacent = 0
				for index = 2, #letters do
					if letters[index] == letters[index - 1] then
						adjacent += 1
					end
				end
				weakest = math.min(weakest, distinct)
				worst = math.max(worst, adjacent)
				if (Plan.cellPlanFor(id) :: any).rides ~= nil then
					v2Distinct = math.min(v2Distinct, distinct)
					v2Adjacent = math.max(v2Adjacent, adjacent)
				end
				table.insert(
					report,
					string.format("%s %s d=%d adj=%d", id, table.concat(letters, ""), distinct, adjacent)
				)
			end
			local rows = table.concat(report, " | ")
			-- A CELL WHOSE RECIPE CARRIES `rides` HAS BEEN BROUGHT TO v2 and meets design 8.5's
			-- count. Task 328f brings C1; the other seven keep the letters their 327c recipes give
			-- them, and `TASKS.md` carries the measurement.
			assert(v2Distinct >= 5, "a v2 cell has fewer than five letters: " .. rows)
			-- AND NO CELL IS A SINGLE LETTER, v2 or not.
			assert(weakest >= 3, "a cell has fewer than three letters: " .. rows)
		end)

		it("follows the plan: a ride's stand takes the ride's letter, a tower's stand takes T", function()
			local plan = Plan.cellPlanFor("C1")
			for _, ride in ipairs(plan.rides) do
				local tower = false
				for _, index in ipairs(Grid.towerStands("C1")) do
					tower = tower or index == ride.atStandIndex
				end
				if not tower then
					expect(Plan.standTypeFor("C1", ride.atStandIndex)).to.equal(ride.kind)
				end
			end
			for _, index in ipairs(Grid.towerStands("C1")) do
				expect(Plan.standTypeFor("C1", index)).to.equal("T")
			end
		end)
	end)

	describe("the census and the planter disagree about nothing but the instrument", function()
		-- THE NAME HALF OF DESIGN 13.2 CASE 10 IS THE WEAKER HALF and is said so: the names come from
		-- `plantOne`'s own return, so that comparison is the planter against itself. The count, the
		-- part total and the four verdict counts are the real cross-instrument check.
		it("counts every tree the planter planted, by name, on one synthetic hillside", function()
			local source = template("SynthBirch", Vector3.new(2, 40, 2), Vector3.new(16, 10, 16))
			local folder = Instance.new("Folder")
			local box = Grid.boundsOf("C1")
			local midZ = (box.minZ + box.maxZ) / 2
			local planted, names = 0, {}
			for index = 1, 6 do
				local x = box.minX + 100 + index * 10
				local made = Planter.plantOne(plantingAt("SynthBirch", x, midZ), source, folder, hillside)
				if made ~= nil then
					planted += 1
					names[made.Name] = (names[made.Name] or 0) + 1
				end
			end
			expect(planted).to.equal(6)
			local report = Census.survey(folder, "C1", hillside, function()
				return 0
			end)
			expect(report.trees).to.equal(planted)
			expect(report.parts).to.equal(planted * 2)
			expect(report.floating).to.equal(0)
			expect(report.sunk).to.equal(0)
			expect(report.tilted).to.equal(0)
			expect(report.noGround).to.equal(0)
			expect(report.inRoad).to.equal(0)
			expect(names["SynthBirch"]).to.equal(6)
			folder:Destroy()
			source:Destroy()
		end)

		it("reads non-zero when it should: lifted, sunk and lying each count one", function()
			local source = template("SynthBirch", Vector3.new(2, 40, 2), Vector3.new(16, 10, 16))
			local box = Grid.boundsOf("C1")
			local midZ = (box.minZ + box.maxZ) / 2
			local baseX = box.minX + 200
			-- ONE DEFECT PER FOLDER, so a count of 1 can only be the tree that was moved.
			local function one(move: ((Model) -> ())?): any
				local folder = Instance.new("Folder")
				local made = Planter.plantOne(plantingAt("SynthBirch", baseX, midZ), source, folder, flat)
				expect(made ~= nil).to.equal(true)
				if move ~= nil then
					move(made :: Model)
				end
				local report = Census.survey(folder, "C1", flat, function()
					return 0
				end)
				folder:Destroy()
				return report
			end
			-- SEATED: the planter put it 0.6 studs into the ground, so nothing reads.
			local seated = one(nil)
			expect(seated.floating).to.equal(0)
			expect(seated.sunk).to.equal(0)
			expect(seated.tilted).to.equal(0)
			expect(seated.broken).to.equal(0)
			expect(math.abs(seated.worstHigh + TreeGround.sinkFor(40)) < 0.01).to.equal(true)
			-- LIFTED 1.0 STUD from there is 0.4 of daylight, which is over the 0.2 tolerance.
			local lifted = one(function(model)
				model:PivotTo(model:GetPivot() + Vector3.new(0, 1, 0))
			end)
			expect(lifted.floating).to.equal(1)
			expect(lifted.sunk).to.equal(0)
			expect(math.abs(lifted.worstHigh - 0.4) < 0.01).to.equal(true)
			-- SUNK 1.2 STUDS further down is 1.8 under, against a 0.6 sink plus the 0.2 tolerance.
			local sunk = one(function(model)
				model:PivotTo(model:GetPivot() - Vector3.new(0, 1.2, 0))
			end)
			expect(sunk.sunk).to.equal(1)
			expect(sunk.floating).to.equal(0)
			expect(math.abs(sunk.worstSink - 1.8) < 0.01).to.equal(true)
			-- LYING: 80 degrees over reads BOTH the lean and the audit's axis arm.
			local lying = one(function(model)
				model:PivotTo(model:GetPivot() * CFrame.Angles(0, 0, math.rad(80)))
			end)
			expect(lying.tilted).to.equal(1)
			expect(lying.broken).to.equal(1)
			expect(lying.brokenBy["trunk-axis-not-Y"]).to.equal(1)
			-- LEANING 3.5 DEGREES is a lean and not a fall -- past the census's 2 and short of the
			-- audit's 5 -- so the tilt reads and the audit does not.
			local leaning = one(function(model)
				model:PivotTo(model:GetPivot() * CFrame.Angles(0, 0, math.rad(3.5)))
			end)
			expect(leaning.tilted).to.equal(1)
			expect(leaning.broken).to.equal(0)
			expect(string.find(Census.line(lifted, "spec"), "floating=1", 1, true) ~= nil).to.equal(true)
			TestKit.note(Census.line(lifted, "spec:lifted"))
			source:Destroy()
		end)

		it("publishes every count where a probe can read it back (V293b)", function()
			local folder = Instance.new("Folder")
			local report = Census.survey(folder, "C1", flat, function()
				return 0
			end, { cliff = 11, skipped = 4, wanted = 300 })
			expect(report.refusedPct).to.equal(5)
			local target = Instance.new("Folder")
			Census.publish(target, report, "deadbeef")
			expect(target:GetAttribute("Census_trees")).to.equal(0)
			expect(target:GetAttribute("Census_refusedCliff")).to.equal(11)
			expect(target:GetAttribute("Census_epoch")).to.equal("deadbeef")
			expect(string.find(target:GetAttribute("Census_line"), "refused=11+4/300", 1, true) ~= nil).to.equal(true)
			-- THE ROWS NO TASK HAS MEASURED READ `UNMEASURED` AND NEVER 0 (design 12.2).
			for key in pairs(Census.UNMEASURED) do
				expect(string.sub(tostring(report[key]), 1, 10)).to.equal("UNMEASURED")
			end
			expect(report.inDitch).never.to.equal(0)
			target:Destroy()
			folder:Destroy()
		end)

		it("the crown rule is by parameter: a wide crown over a road counts, a trunk does not", function()
			local road = Grid.roads()[1]
			-- A POINT ONE STUD CLEAR OF THE FIRST ROAD'S TRUNK RULE, FOUND rather than assumed: the
			-- roads cross, so a midpoint can sit inside the one that crosses it.
			local half = Grid.CONFIG.roadClearStuds / 2
			local x, z = 0, 0
			for along = road.from + 40, road.to - 40, 20 do
				local tryX = if road.axis == "x" then along else road.at + half + 1
				local tryZ = if road.axis == "x" then road.at + half + 1 else along
				if Plan.clearOfEveryRoad(tryX, tryZ) then
					x, z = tryX, tryZ
					break
				end
			end
			expect(x ~= 0 or z ~= 0).to.equal(true)
			expect(Plan.clearOfEveryRoad(x, z)).to.equal(true)
			expect(Plan.clearOfEveryRoad(x, z, 0)).to.equal(true)
			-- ...AND A 12-STUD CROWN HANGS OVER IT.
			expect(Plan.clearOfEveryRoad(x, z, 12)).to.equal(false)
		end)
	end)

	-- ---------------------------------------------------------------- 12. the folders, and the clone's flags

	describe("the planted clone and the three folders", function()
		it("GROUND_IGNORE carries GridForest once, and the three folder names differ", function()
			local seen = 0
			for _, name in ipairs(Forest.GROUND_IGNORE) do
				if name == "GridForest" then
					seen += 1
				end
			end
			expect(seen).to.equal(1)
			expect(Planter.FOLDER).never.to.equal(Planter.GRID_FOLDER)
			expect(Planter.FOLDER).never.to.equal("GridForest")
			expect(Planter.GRID_FOLDER).never.to.equal("GridForest")
			-- EVERY FOLDER THIS MODULE WRITES IS IN THE IGNORE LIST, or a ray stops on our own trunk.
			local listed = {}
			for _, name in ipairs(Forest.GROUND_IGNORE) do
				listed[name] = true
			end
			expect(listed[Planter.FOLDER]).to.equal(true)
			expect(listed[Planter.GRID_FOLDER]).to.equal(true)
		end)

		it("a template whose PIVOT is rotated is planted UPRIGHT, and the old line laid it down", function()
			-- THE DEFECT, AS A FIXTURE. A Model with no `PrimaryPart` carries its bounding box's
			-- rotation in its pivot; 10 of this world's 35 templates do, and theirs is not upright.
			local source = template("PivotTree", Vector3.new(2, 40, 2), Vector3.new(16, 10, 16))
			source.PrimaryPart = nil
			source.WorldPivot = CFrame.new(0, 20, 0) * CFrame.Angles(0, 0, math.rad(80))
			local folder = Instance.new("Folder")
			local box = Grid.boundsOf("C1")
			local x, z = box.minX + 400, (box.minZ + box.maxZ) / 2
			local made = Planter.plantOne(plantingAt("PivotTree", x, z), source, folder, flat)
			expect(made ~= nil).to.equal(true)
			local trunk = made:FindFirstChild("Trunk") :: BasePart
			-- UPRIGHT: the trunk the template drew is still the trunk the player sees.
			expect(trunk.CFrame.UpVector:Dot(Vector3.yAxis) > math.cos(math.rad(2))).to.equal(true)
			local report = Census.survey(folder, "C1", flat, function()
				return 0
			end)
			expect(report.tilted).to.equal(0)
			expect(report.broken).to.equal(0)
			expect(report.floating).to.equal(0)

			-- FAIL FIRST, with the producing line deleted: this is EXACTLY what `plantOne` did
			-- before task 328b -- the pivot forced upright, no `* spin` -- and it lays the tree over.
			local control = source:Clone()
			control.Parent = folder
			control:PivotTo(CFrame.new(x, 200, z) * CFrame.Angles(0, 0, 0))
			local controlTrunk = control:FindFirstChild("Trunk") :: BasePart
			local off = math.deg(math.acos(math.clamp(controlTrunk.CFrame.UpVector:Dot(Vector3.yAxis), -1, 1)))
			expect(off > 70).to.equal(true)
			TestKit.note(string.format("pivot: planted upright; the pre-328b line leaves it %.0f deg over", off))
			folder:Destroy()
			source:Destroy()
		end)

		it("a planted clone streams Atomic AND keeps the foliage flags quieten set (lesson L-060)", function()
			local source = template("FlagTree", Vector3.new(2, 40, 2), Vector3.new(16, 10, 16))
			local folder = Instance.new("Folder")
			local box = Grid.boundsOf("C1")
			local made = Planter.plantOne(
				plantingAt("FlagTree", box.minX + 300, (box.minZ + box.maxZ) / 2),
				source,
				folder,
				flat
			)
			expect(made ~= nil).to.equal(true)
			expect(made.ModelStreamingMode).to.equal(Enum.ModelStreamingMode.Atomic)
			local trunk = made:FindFirstChild("Trunk") :: BasePart
			local crown = made:FindFirstChild("SM_Leaves") :: BasePart
			-- THE TRUNK STILL STOPS A BULLET AND THE LEAF STILL DOES NOT: the Atomic line is after
			-- `quieten` and touches no part property.
			expect(trunk.CanQuery).to.equal(true)
			expect(trunk.Anchored).to.equal(true)
			expect(crown.CanQuery).to.equal(false)
			expect(crown.CanCollide).to.equal(false)
			folder:Destroy()
			source:Destroy()
		end)
	end)
end
