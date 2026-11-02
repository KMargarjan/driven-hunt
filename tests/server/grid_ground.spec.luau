--!nocheck
-- Task 328b: DO THE TREES SIT RIGHT? The contact rule's identity, the template audit and the
-- quarantine, and `ServerStorage.GridCensus` -- design 13.2's cases 1, 2, 3, 10, 11 and 12, plus the
-- two this task's own code needs (the Atomic streaming pair, and the crown rule by parameter).
--
-- CASES 4 TO 9 ARE **328f's** AND ARE NOT HERE: `Places.mask`, `Places.REASON`, the 34/27-stud
-- frontage floors and `Places.standTypeFor` do not exist yet, and a case asserting a function nobody
-- has written is a false-PASS path waiting to happen (design 16's 328e row says exactly that about
-- `grid.spec` case 19). They are queued in `TASKS.md` under 328f.
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
			local function buildWith(): any
				local world = Instance.new("Folder")
				local forest = Instance.new("Folder")
				forest.Name = "OurForest"
				local source = fern()
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
				-- (c) `Places.build`'s own audit closure refuses the template and plants NONE of it,
				-- counting it once in the report.
				local refused = buildWith()
				expect(refused.drawn).to.equal(0)
				expect(refused.report.quarantined).to.equal(1)
				expect(refused.report.quarantinedBy["quarantined"]).to.equal(1)
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

		it("a real template passes its own measured row", function()
			local good = template("GoodTree", Vector3.new(2, 40, 2), Vector3.new(16, 10, 16))
			expect(Planter.auditTemplate(good, "GoodTree")).to.equal(nil)
			expect(Plan.dimsFor("SilverBirch_Var11_LOD_0") ~= nil).to.equal(true)
			good:Destroy()
		end)
	end)

	-- ---------------------------------------------------------------- 10/11. the census

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
