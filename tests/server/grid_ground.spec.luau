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

	-- EVERY CELL'S PLAN, WORKED OUT ONCE. `Plan.plantCell` is the expensive call in this file and
	-- nine cases want the same eight lists; building them per case put the server runner over its
	-- 300 s budget twice (round 2). Pure and deterministic, so one copy is the same as nine.
	local PLANS: { [string]: any } = {}
	local function planOf(cellId: string): any
		-- NEVER inside a fixture that changes what `namesOf` may draw: the quarantine case asks
		-- `Plan.plantCell` directly for exactly that reason.
		if PLANS[cellId] == nil then
			PLANS[cellId] = Plan.plantCell(cellId)
		end
		return PLANS[cellId]
	end

	-- ---------------------------------------------------------------- 1. the contact rule

	describe("the contact rule is TreeGround's, by identity", function()
		it("hold ONE trunk floor and ONE voxel, shared with Grid's bendFacts copies", function()
			-- `Grid` MAY REQUIRE NOTHING BUT `Shotgun`, so `bendFacts` holds its own 34 and 4
			-- (task 328q). This is the assertion that stops the second copy drifting.
			expect(Grid.TRUNK_FLOOR_STUDS).to.equal(Plan.ROAD_TRUNK_FLOOR_STUDS)
			expect(Grid.VOXEL_STUDS).to.equal(require(ReplicatedStorage.Grid:WaitForChild("Relief")).VOXEL)
		end)

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
				for _, item in ipairs(planOf(id)) do
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

	-- ------------------------------------------- 2c. WHICH standing tree is the template (task 328l)

	describe("the template is the instance the row was measured on", function()
		it("nearestScale takes the nearest, then the smaller, and never the first", function()
			-- MEASURED, 2026-11-03: `OurForest` holds 16-125 instances of every one of the 35 names,
			-- scales spanning x1.84. So "the template" has to be chosen, not found.
			expect(Plan.nearestScale({ 0.50, 0.10, 0.30 }, 0.30)).to.equal(3)
			-- FAIL FIRST: the old rule was "the folder's first child". Here that is the worst answer.
			expect(Plan.nearestScale({ 0.50, 0.10, 0.30 }, 0.30) ~= 1).to.equal(true)
			-- A TIE GOES TO THE SMALLER SCALE, so the answer cannot depend on the order.
			expect(Plan.nearestScale({ 0.40, 0.20 }, 0.30)).to.equal(2)
			expect(Plan.nearestScale({ 0.20, 0.40 }, 0.30)).to.equal(1)
			expect(Plan.nearestScale({}, 0.30)).to.equal(nil)
		end)

		it("pickTemplate clones that one out of a folder of three, and not the first child", function()
			local name = "SM_AspenTree_Var02"
			local row = Plan.dimsFor(name)
			expect(row ~= nil).to.equal(true)
			local folder = Instance.new("Folder")
			local made: { Model } = {}
			for _, factor in ipairs({ 1.3, 0.7, 1.0 }) do
				local model = template(name, Vector3.new(2, 40, 2), Vector3.new(16, 10, 16))
				model:ScaleTo(row.scale * factor)
				model.Parent = folder
				table.insert(made, model)
			end
			local picked = Planter.pickTemplate(folder, name)
			expect(picked).to.equal(made[3])
			expect(picked ~= made[1]).to.equal(true)
			-- A FOLDER WITH NONE OF THEM IS NOT AN ERROR (the DEV place), and one unmeasured name
			-- falls back to the first child, because there is no row to be near.
			expect(Planter.pickTemplate(folder, "NoSuchTemplate")).to.equal(nil)
			local other = template("NoSuchTemplate", Vector3.new(2, 40, 2))
			other.Parent = folder
			expect(Planter.pickTemplate(folder, "NoSuchTemplate")).to.equal(other)
			folder:Destroy()
		end)

		it("rescaledReason refuses a template off its row, and the audit carries it", function()
			local name = "SM_AspenTree_Var02"
			local row = Plan.dimsFor(name)
			expect(Plan.rescaledReason(row.scale, row)).to.equal(nil)
			expect(Plan.rescaledReason(row.scale * (1 + Plan.AUDIT_SCALE_FRACTION / 2), row)).to.equal(nil)
			expect(Plan.rescaledReason(row.scale * 1.3, row)).to.equal("template-rescaled")
			expect(Plan.rescaledReason(row.scale * 0.7, row)).to.equal("template-rescaled")
			-- NO ROW IS NOT A FAILURE: there is nothing to be off (design 9.2).
			expect(Plan.rescaledReason(row.scale * 1.3, nil)).to.equal(nil)
			expect(Plan.rescaledReason(row.scale * 1.3, { scale = 0 })).to.equal(nil)
			-- AND IT IS WIRED INTO THE AUDIT, which is what quarantines the name. With this arm
			-- deleted the reason would be `extents` or `part-count`, never this word.
			local off = template(name, Vector3.new(2, 40, 2), Vector3.new(16, 10, 16))
			off:ScaleTo(row.scale * 1.3)
			expect(Planter.auditTemplate(off, name)).to.equal("template-rescaled")
			-- THE CLONE'S PATH MUST NOT CARRY IT: a planted tree's scale is the template's times
			-- `item.scale` by design, so the census's `brokenReason` can never see this word.
			expect(Plan.auditReason(Planter.measureFor(off), row, row.scale * 1.3) == "template-rescaled").to.equal(
				false
			)
			off:Destroy()
		end)

		it("foliageDrop measures this model's crown against this model's trunk", function()
			-- A CROWN THAT HANGS 3 STUDS BELOW THE TRUNK BOX'S FOOT. The trunk is 2 x 40 x 2 with its
			-- centre at y = 20, so its foot is 0; a 10-stud crown centred at y = 2 reaches -3.
			local droopy = template("Droopy", Vector3.new(2, 40, 2))
			local crown = Instance.new("Part")
			crown.Name = "SM_Leaves"
			crown.Size = Vector3.new(16, 10, 16)
			crown.Anchored = true
			crown.CFrame = CFrame.new(0, 2, 0)
			crown.Parent = droopy
			local trunk = droopy:FindFirstChild("Trunk") :: BasePart
			expect(Planter.foliageDrop(droopy, trunk.Position.Y - trunk.Size.Y / 2)).to.be.near(3, 1e-6)
			-- A CROWN ABOVE THE FOOT IS A NEGATIVE NUMBER AND NOT 0: it buys back sink, and 18
			-- `LarchTree_Var01` were counted in the ground for want of exactly that.
			local sound = template("Sound", Vector3.new(2, 40, 2), Vector3.new(16, 10, 16))
			expect(Planter.foliageDrop(sound, 0)).to.be.near(-35, 1e-6)
			-- NO FOLIAGE-NAMED PART AT ALL IS `nil`, which is how a fern keeps its old seat.
			expect(Planter.foliageDrop(template("Bare", Vector3.new(2, 40, 2)), 0)).to.equal(nil)
			droopy:Destroy()
			sound:Destroy()
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
				-- ...so no planting list names it, in any cell. NOT `planOf`: this case is asking
				-- what the plan says WHILE the quarantine stub is up, and a memo from before it
				-- would answer the wrong question.
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
	--
	-- MEASURED FROM THE CURVE AND PERPENDICULAR TO IT (task 328q, design 5.5), through
	-- `Grid.roadCentreAt` and the tangent -- never `road.at`, and never `Places.roadDistance`, which
	-- is the function under test. `bend` is optional, so the same instrument reads both worlds.
	local function roadGap(x: number, z: number, bend: any?): number
		local best = math.huge
		-- THE `from`/`to` TEST IS A GRID TEST (task 328r): a road's span is in grid stations, and
		-- comparing a WORLD x against it put the end of the range up to 60 studs out at 45/60.
		-- `Places.roadDistance`'s own shape, independently here.
		local u, v = Grid.toGrid(x, z, bend)
		for _, road in ipairs(Grid.roads()) do
			if road.axis == "x" then
				if u >= road.from and u <= road.to then
					local d = math.abs(z - Grid.roadCentreAt(road, x, bend))
					best = math.min(best, d / math.sqrt(1 + Grid.bendSlopeZ(x, bend) ^ 2))
				end
			elseif v >= road.from and v <= road.to then
				local d = math.abs(x - Grid.roadCentreAt(road, z, bend))
				best = math.min(best, d / math.sqrt(1 + Grid.bendSlopeX(z, bend) ^ 2))
			end
		end
		return best
	end
	-- A RIDE IS A GRID-COORDINATE SEGMENT (task 328q): straight in the plane, a gentle curve in the
	-- world. So a WORLD point is converted once before it is measured against one.
	local function rideGap(cellId: string, x: number, z: number): number
		local best = math.huge
		local u, v = Grid.toGrid(x, z)
		x, z = u, v
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
			-- GRID IN (task 328r): `road.at` is a grid station and every band below is measured from
			-- it, so the question is `maskGrid`'s. Asked of `mask` these points are read as world
			-- points and mapped BACK, which at 45/60 moves them out of their own band.
			local function at(distance: number): string?
				return Plan.maskGrid(cellId, x, road.at + distance, nil, nil)
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
			for step = 0, 24 do
				local px = box.minX + (box.maxX - box.minX) * step / 24
				for inner = 0, 24 do
					local pz = box.minZ + (box.maxZ - box.minZ) * inner / 24
					local why = Plan.maskGrid(cellId, px, pz, "SilverBirch_Var08_LOD_0", 1)
					expect(why ~= Plan.REASON.CLIFF).to.equal(true)
					expect(why ~= Plan.REASON.GAP).to.equal(true)
				end
			end
		end)
	end)

	describe("no trunk stands in a road or a ride", function()
		it("every planting of every cell clears 34 studs of road and 27 of ride, measured here", function()
			-- ONE CELL CARRIES RIDES TODAY (C1), and a skirt planting lands in a neighbour, so the
			-- ride question is asked of that one cell for every planting of every cell.
			local ridden = "C1"
			expect(#Plan.rideSegments(ridden) > 0).to.equal(true)
			for _, id in ipairs(Grid.cellIds()) do
				local worstRoad, worstRide = math.huge, math.huge
				local trees = 0
				for _, item in ipairs(planOf(id)) do
					local herb = Plan.isHerbName(item.model)
					worstRoad = math.min(worstRoad, roadGap(item.x, item.z))
					if not herb then
						trees += 1
						-- THE RIDE IS THE CELL'S OWN; a skirt planting is inside the NEIGHBOUR, and
						-- `plantCell` masks it against that cell, so ask both.
						worstRide = math.min(worstRide, rideGap(ridden, item.x, item.z))
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
			for step = 0, 40 do
				local x = box.minX + (box.maxX - box.minX) * step / 40
				for inner = 0, 40 do
					local z = box.minZ + (box.maxZ - box.minZ) * inner / 40
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
			expect(checked).to.equal(41 * 41)
		end)

		it("is ONE rule in two spaces: the world question is the grid one through the seam", function()
			-- THE SEAM IS FIVE FUNCTIONS (design 6.3, plus `inFrontage` from 328q round 2):
			-- `roadDistance`, `clearOfEveryRoad`, `mask`, `inFrontage` and `nearestCellTo` take
			-- WORLD coordinates and call `Grid.toGrid` once.
			local box = Grid.boundsOf("C1")
			local checked = 0
			for step = 0, 30 do
				local u = box.minX + (box.maxX - box.minX) * step / 30
				for inner = 0, 30 do
					local v = box.minZ + (box.maxZ - box.minZ) * inner / 30
					local x, z = Grid.toWorld(u, v)
					-- 1. THE WORLD ANSWER IS THE GRID ANSWER, through the map and back.
					expect(Plan.roadDistance(x, z)).to.be.near(Plan.roadDistanceGrid(u, v), 1e-6)
					expect(Plan.mask("C1", x, z)).to.equal(Plan.maskGrid("C1", u, v))
					-- 2. AND THE KERNEL AGREES WITH THIS FILE'S OWN PERPENDICULAR INSTRUMENT, which
					-- is the measurement `Places.roadDistance` is not allowed to be checked by
					-- itself against (`drive-places.md` 10.4 item 3).
					expect(Plan.roadDistanceGrid(u, v)).to.be.near(roadGap(x, z), 1e-6)
					checked += 1
				end
			end
			expect(checked).to.equal(31 * 31)
			-- **AND IT IS NOT THE IDENTITY ANY MORE** (task 328r). At the born 0 this composition
			-- was `x == u` and the case was the inert gate; the shipped bend is 45 / 60, so the
			-- worst lattice point below moves tens of studs between the two spaces and the three
			-- assertions above are a real round trip. Measured here rather than asserted blind.
			local moved = 0
			for step = 0, 30 do
				local u = box.minX + (box.maxX - box.minX) * step / 30
				for inner = 0, 30 do
					local v = box.minZ + (box.maxZ - box.minZ) * inner / 30
					local x, z = Grid.toWorld(u, v)
					moved = math.max(moved, math.abs(x - u), math.abs(z - v))
				end
			end
			expect(Grid.CONFIG.bend.ewStuds).to.equal(45)
			expect(Grid.CONFIG.bend.nsStuds).to.equal(60)
			expect(moved > 10).to.equal(true)
			TestKit.note(
				string.format(
					"%d lattice points: world == grid through the seam, kernel == this file's own gap; the map moves a point up to %.2f studs at bend %d/%d",
					checked,
					moved,
					Grid.CONFIG.bend.ewStuds,
					Grid.CONFIG.bend.nsStuds
				)
			)
		end)

		it("leaves the front cone covering the drive, with 22 degrees to spare", function()
			-- DESIGN 6.4: `standFacing` is a GRID unit vector, so in the world the cone is
			-- perpendicular to the LOCAL road and not to the drive axis. This is the honest statement
			-- of what it still clears, and it is a case rather than a comment.
			local bends = { { ewStuds = 0, nsStuds = 0, harmonic = 1 }, { ewStuds = 45, nsStuds = 60, harmonic = 1 } }
			local worst = 0
			for _, bend in ipairs(bends) do
				local swing = math.max(Grid.bendFacts("x", bend).swingDeg, Grid.bendFacts("z", bend).swingDeg)
				for _, id in ipairs(Grid.cellIds()) do
					for index = 1, Grid.standCount(id) do
						local fx, fz = Plan.standFacing(id, index)
						local u, v = Grid.standGridOf(id, index, bend)
						local x, z = Grid.toWorld(u, v, bend)
						-- THE GRID DIRECTION MAPPED INTO THE WORLD: d(x,z)/du and d(x,z)/dv of the
						-- shear, which are (1, bendZ') and (bendX', 1) up to the Jacobian.
						local wx, wz
						if fx == 0 then
							wx, wz = Grid.bendSlopeX(z, bend) * fz, fz
						else
							wx, wz = fx, Grid.bendSlopeZ(x, bend) * fx
						end
						local length = math.sqrt(wx * wx + wz * wz)
						local off = math.deg(math.acos(math.clamp((wx * fx + wz * fz) / length, -1, 1)))
						expect(off <= swing + 1e-6).to.equal(true)
						worst = math.max(worst, off)
					end
				end
				expect(Plan.CONE.halfDegrees - swing >= 22).to.equal(true)
			end
			-- AT THE BENT AMPLITUDE THE TILT IS REAL AND NOT ZERO, or this case would pass on a map
			-- that never moved.
			expect(worst > 7).to.equal(true)
			TestKit.note(
				string.format(
					"worst facing tilt %.3f deg at 45/60; cone half %d deg leaves %.3f up-drive",
					worst,
					Plan.CONE.halfDegrees,
					Plan.CONE.halfDegrees - worst
				)
			)
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
			-- THE SLACK IS RETIRED (task 328l): the planner's reach IS the census's, because
			-- `nearestScale` and the audit hold `GetScale() / dims.scale` at 1.000. A slack would
			-- now be a second, bigger number for the same crown.
			expect(rawget(Plan, "CROWN_SCALE_SLACK")).to.equal(nil)
			expect(Plan.roadTrunkMin("NoSuchTemplate", 1)).to.be.near(Plan.ROAD_TRUNK_FLOOR_STUDS, 1e-9)
			expect(Plan.rideTrunkMin("NoSuchTemplate", 1)).to.be.near(Plan.RIDE_TRUNK_FLOOR_STUDS, 1e-9)
		end)

		it("and the mask refuses a wide crown where it passes a narrow one, same point", function()
			local id = "C1"
			local box = Grid.boundsOf(id)
			-- THE WIDEST CROWN THE FRONTAGE ALLOWS, and the frontage is why (task 328l): with the
			-- retired slack the set-back is under the 60-stud frontage band, so a group the frontage
			-- refuses reads `frontage` -- the earlier reason in `REASON_ORDER` -- and this case would
			-- be asking about a different rule.
			local plan = Plan.cellPlanFor(id)
			local widest, reach = nil, 0
			for group in pairs(Plan.SPECIES) do
				if Plan.frontageAllowsGroup(plan, group) then
					for _, each in ipairs(Plan.namesOf(group)) do
						local dims = Plan.dimsFor(each)
						if dims ~= nil and dims.crownHalfWidthStuds > reach then
							widest, reach = each, dims.crownHalfWidthStuds
						end
					end
				end
			end
			-- FIND THE POINT RATHER THAN TYPE IT: somewhere clear of every site rule, but inside the
			-- widest crown's own set-back. A hand-picked coordinate lands in a beater corridor or a
			-- front cone the first time a constant moves.
			local scale = 1.2
			local minimum = Plan.roadTrunkMin(widest, scale)
			local foundX, foundZ = nil, nil
			for step = 0, 80 do
				local x = box.minX + (box.maxX - box.minX) * step / 80
				for inner = 0, 80 do
					local z = box.minZ + (box.maxZ - box.minZ) * inner / 80
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
				for _, item in ipairs(planOf(id)) do
					total += 1
					if not Plan.isHerbName(item.model) then
						local inBand = roadGap(item.x, item.z) <= plan.frontage.studs
							or rideGap("C1", item.x, item.z) <= plan.frontage.studs
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
			-- AND IT REALLY CHANGES THE DRAW: a spruce thicket's conifer row goes, its larch row
			-- keeps its own weight, and the three groups it never carried join at 1 -- which is
			-- design 7.2's *"becomes birch and larch"* rather than a bare strip.
			local thicket = Plan.frontageRows(plan, Plan.cellMixNamed("spruceThicket"))
			expect(#thicket).to.equal(#plan.frontage.groups)
			local byGroup = {}
			for _, row in ipairs(thicket) do
				byGroup[row.group] = row.weight
			end
			expect(byGroup.conifer).to.equal(nil)
			expect(byGroup.young).to.equal(2)
			expect(byGroup.birch).to.equal(1)
			expect(byGroup.aspen).to.equal(1)
			expect(byGroup.fieldOak).to.equal(1)
			-- A CLEARING STAYS A CLEARING: an empty mix is not a licence to invent a hedge.
			expect(#Plan.frontageRows(plan, Plan.cellMixNamed("clearing"))).to.equal(0)
		end)
	end)

	describe("the ferns", function()
		it("stand clear of the ditch and the verge, and never more than the cap a cell", function()
			for _, id in ipairs(Grid.cellIds()) do
				local ferns = 0
				for _, item in ipairs(planOf(id)) do
					if Plan.isHerbName(item.model) then
						ferns += 1
						-- DEFECT F-5: measured from the ROAD CENTRELINE, so 34 is the verge's far
						-- edge and no bracken stands in the 22-34 band design 7.1 keeps bare.
						expect(roadGap(item.x, item.z) >= Plan.VERGE_STUDS.to).to.equal(true)
					end
				end
				-- THE CAP IS A GUARD, NOT A MEASUREMENT: C1's bands offer far fewer sites than 400,
				-- so this line cannot fail today and is here to notice a spacing change that would
				-- make it bite (round 1, note).
				expect(ferns <= Plan.FERN_CAP).to.equal(true)
			end
			-- AND THE BAND ITSELF STARTS AT 34, not at the cell edge.
			local plan = Plan.cellPlanFor("C1")
			expect(plan.fernBand.fromStuds).to.equal(Plan.VERGE_STUDS.to)
			for _, rect in ipairs(Plan.fernBands("C1", plan)) do
				-- A GRID RECT, AND THE BAND IS AN AXIS-ALIGNED GRID RULE (task 328r): `fernBands`
				-- insets by `fromStuds` from the road's grid line, so that is the distance to
				-- assert. `roadDistanceGrid` answers the PERPENDICULAR distance, which on a bend is
				-- `cos(swing)` of it -- 33.73 where the band starts at 34 -- so the band's inner
				-- edge counts as verge and the mask refuses it. That is the conservative side and
				-- it is asserted as its own bound rather than left to be discovered.
				local axis = math.min(
					math.abs(rect.minZ - Grid.roadsOf("C1").main.at),
					math.abs(rect.minZ - Grid.roadsOf("C1").muster.at),
					math.abs(rect.minX - Grid.roadsOf("C1").west.at),
					math.abs(rect.minX - Grid.roadsOf("C1").east.at)
				)
				expect(axis >= Plan.VERGE_STUDS.to - 1e-9).to.equal(true)
				local swing = math.max(Grid.bendFacts("x").swingDeg, Grid.bendFacts("z").swingDeg)
				expect(
					Plan.roadDistanceGrid(rect.minX, rect.minZ)
						>= Plan.VERGE_STUDS.to * math.cos(math.rad(swing)) - 1e-9
				).to.equal(true)
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

	-- ------------------------------------- round 2: the arms, the rides and the bias, each BITING

	describe("the rides are where the recipe says, measured off Grid and not off the mask", function()
		it("one segment per ride row, from its stand along its facing, and the X cut across it", function()
			local id = "C1"
			local plan = Plan.cellPlanFor(id)
			local segments = Plan.rideSegments(id)
			expect(#segments).to.equal(#plan.rides)
			for index, ride in ipairs(plan.rides) do
				local seg = segments[index]
				-- THE GRID POINT (task 328q): `rideSegments` is grid-coordinate, so the thing it has
				-- to agree with is `standGridOf` and not the world position.
				local su, sv = Grid.standGridOf(id, ride.atStandIndex)
				local spot = Vector3.new(su, 0, sv)
				local fx, fz = Plan.standFacing(id, ride.atStandIndex)
				expect(seg.kind).to.equal(ride.kind)
				if ride.kind == "X" then
					-- ACROSS the sight line at the cone's far edge, centred on it, perpendicular.
					local mx = (seg.ax + seg.bx) / 2
					local mz = (seg.az + seg.bz) / 2
					expect(mx).to.be.near(spot.X + fx * Plan.CUT_CROSS_STUDS, 1e-6)
					expect(mz).to.be.near(spot.Z + fz * Plan.CUT_CROSS_STUDS, 1e-6)
					local dx, dz = seg.bx - seg.ax, seg.bz - seg.az
					expect(math.sqrt(dx * dx + dz * dz)).to.be.near(ride.lengthStuds, 1e-6)
					-- PERPENDICULAR: the dot product with the facing is zero.
					expect(dx * fx + dz * fz).to.be.near(0, 1e-6)
				else
					expect(seg.ax).to.be.near(spot.X, 1e-6)
					expect(seg.az).to.be.near(spot.Z, 1e-6)
					expect(seg.bx).to.be.near(spot.X + fx * ride.lengthStuds, 1e-6)
					expect(seg.bz).to.be.near(spot.Z + fz * ride.lengthStuds, 1e-6)
				end
			end
		end)

		it("C1's L rides stand at the two depths SWARM_DESIGN 2.2 names, 560 and 780", function()
			local main = Grid.roadsOf("C1").main
			-- THEY ARE **GRID** DEPTHS, AND THE BEND MOVED THEM (task 328r). SWARM 2.2's 560 and
			-- 780 are `flankFirstStuds + k * flankSpacing` at the straight set-back of 340; at
			-- 45/60 the set-back solves to 366, so the two depths are 586 and 806. The WORLD z is
			-- a third number again (578.83 and 813.49, measured), because the stand sits on the
			-- road's curve -- all three are asserted so none can be read as another.
			local straight = { ewStuds = 0, nsStuds = 0, harmonic = 1 }
			expect(select(2, Grid.standGridOf("C1", 9, straight)) - main.at).to.be.near(560, 1e-6)
			expect(select(2, Grid.standGridOf("C1", 14, straight)) - main.at).to.be.near(780, 1e-6)
			expect(select(2, Grid.standGridOf("C1", 9)) - main.at).to.be.near(586, 1e-6)
			expect(select(2, Grid.standGridOf("C1", 14)) - main.at).to.be.near(806, 1e-6)
			expect(Grid.standPosition("C1", 9).Z - main.at).to.be.near(578.83, 0.01)
			expect(Grid.standPosition("C1", 14).Z - main.at).to.be.near(813.49, 0.01)
			-- **THE DEPTH IS A GRID FACT AND THAT IS WHY IT SURVIVES THE BEND** (task 328q): it is
			-- `flankFirstStuds + k * flankSpacing` at ANY amplitude, driven here by parameter. The
			-- design's 5.4 names 586 / 806 for these two at 45/60, and those are the GRID depths --
			-- `standPosition(...).Z - main.at` reads 578.83 / 813.49 there, because `bendZ` moves the
			-- stand's world z as well. 328r is the task that re-transcribes them.
			local bent = { ewStuds = 45, nsStuds = 60, harmonic = 1 }
			for _, bend in ipairs({ { ewStuds = 0, nsStuds = 0, harmonic = 1 }, bent }) do
				local first = Grid.flankFirstStuds(bend)
				local _, v9 = Grid.standGridOf("C1", 9, bend)
				local _, v14 = Grid.standGridOf("C1", 14, bend)
				expect(v9 - main.at).to.be.near(first + Grid.CONFIG.flankSpacingStuds, 1e-9)
				expect(v14 - main.at).to.be.near(first + 2 * Grid.CONFIG.flankSpacingStuds, 1e-9)
			end
			expect(Grid.flankFirstStuds(bent) + 2 * Grid.CONFIG.flankSpacingStuds).to.equal(806)
			-- ...AND A FLANK STAND LOOKS ACROSS THE CELL, not along its own road.
			local wx, wz = Plan.standFacing("C1", 9)
			expect(wx).to.equal(1)
			expect(wz).to.equal(0)
			local ex, ez = Plan.standFacing("C1", 14)
			expect(ex).to.equal(-1)
			expect(ez).to.equal(0)
		end)

		it("and the ride arm BITES: the mask refuses points for it, and none without the rides", function()
			local id = "C1"
			local seg = Plan.rideSegments(id)[1]
			-- ON THE V RIDE's own centreline, a third of the way up it -- far from the road bands.
			local x = seg.ax + (seg.bx - seg.ax) / 3
			local z = seg.az + (seg.bz - seg.az) / 3
			expect(Plan.maskGrid(id, x, z, nil, nil)).to.equal(Plan.REASON.RIDE)
			-- ...AND JUST OUTSIDE IT, the same depth, is not refused for a ride. **`maskGrid`, like
			-- the positive half above** (round 1, finding 2): asked of `mask`, this grid point is
			-- read as a world one and `Grid.toGrid` moves it ~60 studs before the mask sees it, so
			-- the control answered "not in the band" for a point that was never in it -- it held
			-- with `RIDE_CLEAR_STUDS` set to 0.
			local out = Plan.maskGrid(id, x + Plan.RIDE_CLEAR_STUDS, z, nil, nil)
			expect(out ~= Plan.REASON.RIDE).to.equal(true)
			-- A COUNTED BITE over the whole cell, so an empty `rides` row cannot pass this.
			local box = Grid.boundsOf(id)
			local hits = 0
			for step = 0, 40 do
				local px = box.minX + (box.maxX - box.minX) * step / 40
				for inner = 0, 40 do
					local pz = box.minZ + (box.maxZ - box.minZ) * inner / 40
					-- A GRID RECTANGLE WALKED IN GRID COORDINATES (round 1, note 2).
					if Plan.maskGrid(id, px, pz, nil, nil) == Plan.REASON.RIDE then
						hits += 1
					end
				end
			end
			assert(hits > 8, string.format("the ride arm refused only %d of 1,681 lattice points", hits))
		end)
	end)

	describe("each exclusion arm comes back at its own constant, and not just outside it", function()
		it("the front cone, near and far, with its twin behind the stand", function()
			local id = "C1"
			-- STAND 6, NOT 4: the X cut at stand 3 crosses 140 studs ahead of the middle of the line
			-- and its own crown set-back reaches stand 4's far-cone point, so that point answers
			-- `crown` before it answers `cone` (round 2's first harness run). Stand 6 is 300 studs
			-- east of the cut and 150 from the V ride.
			local index = 6
			-- THE WHOLE CASE IN GRID COORDINATES (round 1, note 2): `standFacing` is a GRID unit
			-- vector, so a world stand position plus `fx * reach` is a point in neither space --
			-- it drifts up to `0.128 * reach` laterally at 45/60. The cone, the stand and the
			-- zones are all grid facts, so the point and the question are both grid ones.
			local sx, sz = Grid.standGridOf(id, index)
			local fx, fz = Plan.standFacing(id, index)
			local reach = Plan.CONE.nearStuds - 4
			expect(Plan.maskGrid(id, sx + fx * reach, sz + fz * reach, nil, nil)).to.equal(Plan.REASON.CONE)
			-- BEHIND HIM is not his cone (it is outside the cell, and nothing else refuses it).
			expect(Plan.maskGrid(id, sx - fx * reach, sz - fz * reach, nil, nil)).to.equal(nil)
			-- THE FAR BAND is a rule about YOUNG GROWTH and about nothing else: same point, two
			-- templates, two answers.
			local far = (Plan.CONE.nearStuds + Plan.CONE.farStuds) / 2
			local fx2, fz2 = sx + fx * far, sz + fz * far
			expect(Plan.maskGrid(id, fx2, fz2, "LarchTree_Var01", 0.5)).to.equal(Plan.REASON.CONE)
			expect(Plan.maskGrid(id, fx2, fz2, "SilverBirch_Var08_LOD_0", 1)).to.equal(nil)
			-- ...AND PAST THE CONE even a larch stands.
			local past = Plan.CONE.farStuds + 20
			expect(Plan.maskGrid(id, sx + fx * past, sz + fz * past, "LarchTree_Var01", 0.5)).to.equal(nil)
		end)

		it("a beater corridor, on its own jittered centreline and 15 studs off it", function()
			local id = "C1"
			local box = Grid.boundsOf(id)
			local z = box.minZ + 700
			local x = Plan.corridorXAt(id, 1, z)
			-- A GRID x AT A GRID z, so the question is `maskGrid`'s (task 328r).
			expect(Plan.maskGrid(id, x, z, nil, nil)).to.equal(Plan.REASON.CORRIDOR)
			-- BOTH CONTROLS IN THE SAME SPACE AS THE HIT (round 1, finding 2): `off` is 15 studs
			-- against a 5-stud half-width, and `Grid.bendX(-4386)` is -59.97, so asked of `mask`
			-- these two held with `off` set to 0.
			local off = Plan.CORRIDOR.halfStuds * 3
			expect(Plan.maskGrid(id, x + off, z, nil, nil) ~= Plan.REASON.CORRIDOR).to.equal(true)
			expect(Plan.maskGrid(id, x - off, z, nil, nil) ~= Plan.REASON.CORRIDOR).to.equal(true)
			-- THE WANDER IS REAL: the centreline is not the same x at every depth.
			expect(math.abs(Plan.corridorXAt(id, 1, z) - Plan.corridorXAt(id, 1, z + Plan.CORRIDOR.waveStuds / 2)) > 1).to.equal(
				true
			)
		end)

		it("D1's field, inside the headland and in it", function()
			local rect = Plan.fieldRect("D1")
			expect(rect ~= nil).to.equal(true)
			local plan = Plan.cellPlanFor("D1")
			local midX = (rect.minX + rect.maxX) / 2
			local midZ = (rect.minZ + rect.maxZ) / 2
			-- `fieldRect` IS A GRID RECTANGLE, so the question is `maskGrid`'s (task 328r). Asked of
			-- `mask`, a grid point is read as a world point and mapped BACK through `toGrid`, which
			-- at 45/60 moves it up to 60 studs out of its own field.
			expect(Plan.maskGrid("D1", midX, midZ, nil, nil)).to.equal(Plan.REASON.FIELD)
			-- THE HEADLAND IS NOT THE FIELD: that is where the hedge and the lone oaks stand.
			local inHeadland = rect.minZ + plan.field.headlandStuds / 2
			expect(Plan.maskGrid("D1", midX, inHeadland, nil, nil) ~= Plan.REASON.FIELD).to.equal(true)
			-- ...AND NO OTHER CELL HAS ONE.
			expect(Plan.fieldRect("C1")).to.equal(nil)
			-- IT BITES: D1 plants nothing inside the field.
			local inside = 0
			for _, item in ipairs(planOf("D1")) do
				-- A ROW CARRIES THE WORLD POINT; `rect` IS A GRID RECT (task 328r).
				local gx, gz = Grid.toGrid(item.x, item.z)
				if
					gx > rect.minX + plan.field.headlandStuds
					and gx < rect.maxX - plan.field.headlandStuds
					and gz > rect.minZ + plan.field.headlandStuds
					and gz < rect.maxZ - plan.field.headlandStuds
				then
					inside += 1
				end
			end
			expect(inside).to.equal(0)
		end)

		it("a clearing refuses, and the zone beside it does not", function()
			-- B1 AND NOT C1 (task 335): C1 is one birch wood with no cut left in it, so the cell
			-- this arm is asked about has to be one that still declares a clearing.
			local id = "B1"
			local plan = Plan.cellPlanFor(id)
			local empty, solid = nil, nil
			for _, zone in ipairs(plan.zones) do
				if zone.spacingStuds <= 0 then
					empty = Plan.zoneRect(id, zone)
				elseif solid == nil then
					solid = Plan.zoneRect(id, zone)
				end
			end
			expect(empty ~= nil).to.equal(true)
			-- A `zoneRect` CENTRE IS A GRID POINT (round 1, note 2).
			expect(Plan.maskGrid(id, (empty.minX + empty.maxX) / 2, (empty.minZ + empty.maxZ) / 2, nil, nil)).to.equal(
				Plan.REASON.CLEARING
			)
		end)

		it("the stand and tower arms are SUBSUMED by the road band, and that is why they cannot fire", function()
			-- EVERY STAND IN THIS WORLD SITS ON A ROAD CENTRELINE (`Grid.standPosition`), and the
			-- road's own trunk-free band is 34 studs -- wider than `POST_CLEAR_STUDS` 20 and
			-- `TOWER_CLEAR_STUDS` 24. So design 7.4's clearance is MET by a stronger rule and the
			-- two arms are unreachable. Asserted rather than deleted: a stand off a road would need
			-- them, and this case is what would notice.
			expect(Plan.POST_CLEAR_STUDS < Plan.ROAD_TRUNK_FLOOR_STUDS).to.equal(true)
			expect(Plan.TOWER_CLEAR_STUDS < Plan.ROAD_TRUNK_FLOOR_STUDS).to.equal(true)
			for _, id in ipairs(Grid.cellIds()) do
				for index = 1, Grid.standCount(id) do
					-- 1e-3 AND NOT 1e-6: `standPosition` returns a `Vector3`, whose components are
					-- float32 (measured residual 1.87e-4 at 45/60). The arithmetic is exact.
					local spot = Grid.standPosition(id, index)
					expect(roadGap(spot.X, spot.Z)).to.be.near(0, 1e-3)
				end
			end
			-- AND NO PLANTING OF ANY CELL IS INSIDE EITHER CLEARANCE, which is the fact that matters.
			-- ONE value over every pair and ONE `expect`: an expectation per pair is 168,000 of them
			-- and it timed the server runner out (round 2's first harness run).
			local worst = math.huge
			for _, id in ipairs(Grid.cellIds()) do
				local spots = {}
				for other = 1, Grid.standCount(id) do
					table.insert(spots, Grid.standPosition(id, other))
				end
				for _, item in ipairs(planOf(id)) do
					if not Plan.isHerbName(item.model) then
						for _, spot in ipairs(spots) do
							local dx, dz = item.x - spot.X, item.z - spot.Z
							worst = math.min(worst, dx * dx + dz * dz)
						end
					end
				end
			end
			assert(
				worst > Plan.TOWER_CLEAR_STUDS * Plan.TOWER_CLEAR_STUDS,
				string.format("a trunk stands %.2f st from a stand", math.sqrt(worst))
			)
		end)

		it("noTrees is a declared reason with no data behind it yet, and the spec says so", function()
			-- THE SCARP IS B2's AND IT IS 328h's (the bake). Until a recipe carries a `noTrees` row
			-- the arm cannot fire, and a case claiming otherwise would be a false pass.
			for _, id in ipairs(Grid.cellIds()) do
				expect((Plan.cellPlanFor(id) :: any).noTrees).to.equal(nil)
			end
			local seen = false
			for _, reason in ipairs(Plan.REASON_ORDER) do
				seen = seen or reason == Plan.REASON.NO_TREES
			end
			expect(seen).to.equal(true)
		end)
	end)

	describe("the fern floor is ferns", function()
		it("every item a fern band produces is ground cover, in a W/M/B/Bo zone", function()
			-- ROUND 1, FINDING 1: the frontage rewrite was reaching the herb layer, dropping the one
			-- `fern` row and putting the four TREE groups back -- full trees at the herb band's own
			-- 0.8-1.7 scale, on the floor's neighbour grid.
			local wrong, worstName = 0, ""
			local counts, total, mine = {}, 0, 0
			for _, id in ipairs(Grid.cellIds()) do
				local ferns = 0
				for _, item in ipairs(planOf(id)) do
					if item.band == "herb" then
						ferns += 1
						-- A PLANTING ROW CARRIES THE **WORLD** POINT and `zoneAt` takes GRID
						-- coordinates (task 328r): at 45/60 the two differ by up to 60 studs, which
						-- read 353 ferns as standing outside every FERN_MIXES zone.
						local gx, gz = Grid.toGrid(item.x, item.z)
						local zone = Plan.zoneAt(id, gx, gz)
						if not Plan.isHerbName(item.model) or zone == nil or not Plan.FERN_MIXES[zone.mix] then
							wrong += 1
							worstName = item.model
						end
					end
				end
				table.insert(counts, string.format("%s=%d", id, ferns))
				total += ferns
				if id == "C1" then
					mine = ferns
				end
			end
			assert(wrong == 0, string.format("%d herb-band item(s) are not ground cover, e.g. %s", wrong, worstName))
			-- THE BITE: this cell's own floor exists. A per-cell `> 0` would be a bet on seven other
			-- recipes whose zones are mostly thicket, scrub and larch -- none of them `FERN_MIXES`.
			assert(mine > 0 and total > 0, "no ferns: " .. table.concat(counts, " "))
			-- AND THE RULE ITSELF: a mix carrying ground cover is passed through untouched.
			local plan = Plan.cellPlanFor("C1")
			local floor = Plan.cellMixNamed("fernFloor")
			expect(#Plan.frontageRows(plan, floor)).to.equal(#floor)
			expect(Plan.frontageRows(plan, floor)[1].group).to.equal("fern")
			expect(Plan.frontageGroupFor(plan, "fern", 0.5)).to.equal("fern")
			-- ...WHILE A CONIFER IN A FRONTAGE BAND IS RE-DRAWN from the four groups.
			local drawn = Plan.frontageGroupFor(plan, "conifer", 0.5)
			expect(drawn ~= "conifer").to.equal(true)
			expect(Plan.frontageAllowsGroup(plan, drawn)).to.equal(true)
			-- ...AND AN ALLOWED GROUP IS KEPT, so the zone's own character survives where it can.
			expect(Plan.frontageGroupFor(plan, "birch", 0.5)).to.equal("birch")
			-- THE TWO DOORS ANSWER ONE RULE: the template one is the group one through `groupOf`.
			expect(Plan.frontageAllows(plan, "SilverBirch_Var08_LOD_0")).to.equal(true)
			expect(Plan.frontageAllows(plan, "Old_Spruce_Tree_Var01_LOD_0")).to.equal(false)
			expect(Plan.frontageAllowsGroup(plan, "birch")).to.equal(true)
			expect(Plan.frontageAllowsGroup(plan, "conifer")).to.equal(false)
		end)
	end)

	describe("the relief bias is a function of the ground, and it bites", function()
		it("the same cell on a low hillside and on a high one draws different woods", function()
			-- NO SHIPPED RECIPE CARRIES `reliefBias` SINCE TASK 335 -- C1 was the only one and
			-- Karen's C1 is one species -- so this case hands `plantCell` a plan of its own: C1's
			-- row with a single `mixedWood` zone over the whole cell that declares the bias.
			local id = "C1"
			local cell = Grid.cellOf(id)
			local real = Plan.cellPlanFor
			local mine = table.clone(real(id))
			mine.zones = {
				{
					at = { 0, 0, 1, 1 },
					mix = "mixedWood",
					spacingStuds = 30,
					band = "wood",
					reliefBias = true,
					jitter = 1.0,
				},
			}
			Plan.cellPlanFor = function(which)
				return if which == id then mine else real(which)
			end
			Plan.forgetCells()
			local low = cell.relief.minY + 0.1 * cell.relief.spreadStuds
			local high = cell.relief.minY + 0.9 * cell.relief.spreadStuds
			local function histogram(heightAt): { [string]: number }
				local out: { [string]: number } = {}
				for _, item in ipairs(Plan.plantCell(id, heightAt)) do
					local group = Plan.groupOf(item.model) or "?"
					out[group] = (out[group] or 0) + 1
				end
				return out
			end
			local ok, err = pcall(function()
				local cold = histogram(function()
					return low
				end)
				local warm = histogram(function()
					return high
				end)
				-- UNDER hn .30 a broadleaf zone draws spruce; OVER .70 a spruce zone draws birch.
				expect((cold.conifer or 0) > (warm.conifer or 0)).to.equal(true)
				expect((warm.birch or 0) > (cold.birch or 0)).to.equal(true)
				-- AND WITH NO READER the bias is simply off -- the plan every caller before 328f got.
				local none = histogram(nil)
				expect((none.conifer or 0) < (cold.conifer or 0)).to.equal(true)
				-- THE FERN FLOOR IS NEVER BIASED: a fern is not a broadleaf zone.
				expect(cold.fern).to.equal(none.fern)
			end)
			-- THE SHIPPED PLAN GOES BACK whatever the assertions did, so no later case in this file
			-- or any other reads a synthetic recipe.
			Plan.cellPlanFor = real
			Plan.forgetCells()
			assert(ok, tostring(err))
		end)

		it("no shipped recipe declares it, which is what task 335 did to C1", function()
			local carrying = {}
			for _, id in ipairs(Grid.cellIds()) do
				for _, zone in ipairs(Plan.cellPlanFor(id).zones) do
					if zone.reliefBias == true then
						table.insert(carrying, id .. "/" .. zone.mix)
					end
				end
			end
			assert(#carrying == 0, "reliefBias is shipped on " .. table.concat(carrying, " "))
		end)
	end)

	-- ------------------------------------------- task 335: C1 is ONE SPECIES, WALL TO WALL

	-- KAREN, 2026-11-08, on a top-down frame of C1: *"so we start with this that all has to be
	-- forest no free spot excep road so in one terrain maik all birch trees"*. Two claims, two
	-- cases, and both die if `mixedRolling`'s v5 zones are reverted.
	describe("C1 is one birch wood with no free ground in it", function()
		it("offers no stem that is not a birch, understorey and every zone included", function()
			local birch = {}
			for _, name in ipairs(Plan.SPECIES.birch) do
				birch[name] = true
			end
			local wrong, counts = {}, {}
			for _, item in ipairs(Plan.plantCell("C1", nil)) do
				local group = Plan.groupOf(item.model) or "?"
				counts[group] = (counts[group] or 0) + 1
				-- THE FERN FLOOR IS GROUND COVER AND NOT A TREE, so it is not in the claim.
				if not Plan.isHerbName(item.model) and not birch[item.model] then
					table.insert(wrong, item.model)
				end
			end
			local seen = {}
			for group, n in pairs(counts) do
				table.insert(seen, string.format("%s=%d", group, n))
			end
			table.sort(seen)
			assert(
				#wrong == 0,
				string.format(
					"%d non-birch stem(s), e.g. %s -- %s",
					#wrong,
					tostring(wrong[1]),
					table.concat(seen, " ")
				)
			)
			-- AND THE CELL IS NOT EMPTY: a plan that plants nothing would pass the line above.
			assert((counts.birch or 0) > 1500, "C1 plants only " .. tostring(counts.birch) .. " birch")
			TestKit.note("C1 one species: " .. table.concat(seen, " "))
		end)

		it("leaves no open ground off the roads, the rides, the corridors and the stands", function()
			-- THE BOUND (dispatch 335): on a 20-stud lattice over the cell's interior, at most 3 %
			-- of the points that are NOT road, ditch, verge, ride, corridor, stand, tower or cone
			-- may have no trunk within 25 studs. Those eight are what a stand and a beater need.
			local ID, STEP, REACH, BOUND = "C1", 20, 25, 0.03
			local EXEMPT = {
				road = true,
				ditch = true,
				verge = true,
				ride = true,
				corridor = true,
				stand = true,
				tower = true,
				cone = true,
			}
			local CELLW = 50
			local hash = {}
			for _, item in ipairs(Plan.plantCell(ID, nil)) do
				if not Plan.isHerbName(item.model) then
					local key = math.floor(item.x / CELLW) .. ":" .. math.floor(item.z / CELLW)
					local bucket = hash[key]
					if bucket == nil then
						bucket = {}
						hash[key] = bucket
					end
					table.insert(bucket, item)
				end
			end
			local function covered(x: number, z: number): boolean
				local gx, gz = math.floor(x / CELLW), math.floor(z / CELLW)
				for dx = -1, 1 do
					for dz = -1, 1 do
						local bucket = hash[(gx + dx) .. ":" .. (gz + dz)]
						if bucket ~= nil then
							for _, item in ipairs(bucket) do
								local ex, ez = item.x - x, item.z - z
								if ex * ex + ez * ez <= REACH * REACH then
									return true
								end
							end
						end
					end
				end
				return false
			end
			local box = Grid.boundsOf(ID)
			local asked, open = 0, 0
			for u = box.minX, box.maxX, STEP do
				for v = box.minZ, box.maxZ, STEP do
					local why = Plan.maskGrid(ID, u, v)
					if why == nil or EXEMPT[why] ~= true then
						asked += 1
						-- A PLANTING ROW CARRIES THE **WORLD** POINT and the lattice is in GRID
						-- coordinates (task 328r's own trap), so the point is mapped once.
						local wx, wz = Grid.toWorld(u, v)
						if not covered(wx, wz) then
							open += 1
						end
					end
				end
			end
			assert(asked > 3000, "the lattice asked only " .. tostring(asked) .. " points")
			TestKit.note(
				string.format(
					"C1 open ground: %d/%d = %.2f%% (<= %.0f%%)",
					open,
					asked,
					open / asked * 100,
					BOUND * 100
				)
			)
			assert(
				open / asked <= BOUND,
				string.format("C1 open ground %d/%d = %.2f%%", open, asked, open / asked * 100)
			)
		end)

		it("a plantation is planted in rows: A2's larch zones hold their x line", function()
			local plan = Plan.cellPlanFor("A2")
			local rowZones = 0
			for _, zone in ipairs(plan.zones) do
				if zone.rows == "NS" then
					rowZones += 1
				end
			end
			expect(rowZones > 0).to.equal(true)
			-- THE SITES IN A ROW ZONE SIT ON A SMALL NUMBER OF DISTINCT x VALUES, because only the
			-- depth wanders. Count them against the same zone's own spacing.
			local lines: { [number]: boolean } = {}
			local counted = 0
			for _, item in ipairs(planOf("A2")) do
				for _, zone in ipairs(plan.zones) do
					if zone.rows == "NS" then
						local rect = Plan.zoneRect("A2", zone)
						-- THE ROWS ARE GRID LINES AND THE RECT IS A GRID RECT (task 328r). A row's
						-- WORLD x varies along the row by `bendX(z)` -- that IS the bend -- so
						-- counting distinct world x would give one "line" per tree at 45/60 and the
						-- case would be measuring the map rather than the planter.
						local gx, gz = Grid.toGrid(item.x, item.z)
						if
							gx >= rect.minX
							and gx <= rect.maxX
							and gz >= rect.minZ
							and gz <= rect.maxZ
							and item.band ~= "herb"
						then
							lines[math.floor(gx * 1000 + 0.5)] = true
							counted += 1
						end
					end
				end
			end
			expect(counted > 50).to.equal(true)
			local distinct = 0
			for _ in pairs(lines) do
				distinct += 1
			end
			-- FAR fewer lines than trees: a jittered grid would give one x per tree.
			expect(distinct * 4 < counted).to.equal(true)
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
				-- `Planter.FOREST_FOLDER` AND NOT THE LITERAL (task 328g): the list is asserted
				-- against the CONSTANT the planter and the tool both use, so a rename moves both or
				-- fails here.
				if name == Planter.FOREST_FOLDER then
					seen += 1
				end
			end
			expect(seen).to.equal(1)
			expect(Planter.FOLDER).never.to.equal(Planter.GRID_FOLDER)
			expect(Planter.FOREST_FOLDER).to.equal("GridForest")
			expect(Planter.FOLDER).never.to.equal(Planter.FOREST_FOLDER)
			expect(Planter.GRID_FOLDER).never.to.equal(Planter.FOREST_FOLDER)
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
