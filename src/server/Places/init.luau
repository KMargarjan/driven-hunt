--!strict
-- Places (server): THE ONE WRITER OF `Workspace.DrivePlaces`, and the only thing in this system that
-- touches an Instance at all.
--
-- Task 193. Karen, 2026-10-15: *"4 hunting places ... be sure you do it properly not fake it or
-- broken"*.
--
-- WHAT IT DOES. It takes the pure plan from `ReplicatedStorage.Places` -- a list of
-- (model, x, z, scale, yaw) -- clones each template out of the Studio content this place already
-- holds, measures the terrain under the TRUNK'S OWN FOOTPRINT, and hands those measurements to
-- `TreeGround` to decide where the trunk/root junction goes. It decides nothing itself: every number
-- comes either from the plan or from the world.
--
-- WHY IT PLANTS INSTEAD OF THE PLACE HOLDING THE TREES. `Workspace.OurForest` is Studio content --
-- *"nothing under `src/` creates it, no Rojo path owns it, and it is saved with the place, so no
-- commit can move it"* (task 199) -- which is why task 199 needed a 704-line tool to put its trees
-- back on the ground after Karen's *"look at the trees wtf"*. Four more hand-built places would be
-- four more of those. `docs/PROJECT_CONTEXT.md` names it as what killed the previous game:
-- *"Everything lived in the cloud place file: no diffs, no history, no rollback."* Everything this
-- module plants is a diff.
--
-- THE PRECEDENT IS `Lobby.Build`, which plants the lodge's tree ring the same way. Its SHAPE is
-- borrowed and its CODE is not: it is documented as *the one writer of every part in
-- `Workspace.Lobby`*, and reaching into it from a second system is the owner collision rule 3
-- exists to stop. The arithmetic both share is `TreeGround`, and there is one copy of that.
--
-- IT PLANTS ONCE, AT BOOT, FOR EVERY PLACE -- not per drive with a tear-down. Measured: 200 models
-- clone and seat in 0.09 s, so all four cost about a second, once. The alternative was rebuilding
-- per drive, and the reason against it is a failure mode rather than a cost: a tear-down that misses
-- leaves a forest standing in the field the next drive is shot across, and nothing would catch it
-- until Karen saw it.
--
-- IN THE DEV PLACE IT DOES NOTHING, LOUDLY, ONCE. `ForestTestBoot` already returns early unless
-- `Map.EXPECTED_WORLD == "forest-test"`, and neither `OurForest` nor `Session` exists in DEV, so
-- `build` with no templates folder prints one line and plants nothing.
--
-- Design: docs/design/drive-places.md
-- Note:   docs/research/2026-10-17-four-driven-hunt-places.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Plan = require(ReplicatedStorage:WaitForChild("Places"))
local Ground = require(script:WaitForChild("Ground"))
local TreeGround = require(ReplicatedStorage:WaitForChild("TreeGround"))
local Forest = require(ReplicatedStorage:WaitForChild("ForestTest"))

local Places = {}

-- WHERE THE PLANTED WOOD LIVES: one folder, one child per place. Named for what it is, and NOT
-- `OurForest` or `Foliage` -- a reader has to be able to tell at a glance which trees a commit owns
-- and which are Karen's Studio content that rule 7 protects.
-- IT IS ALSO THE NAME `ForestTest.GROUND_IGNORE` CARRIES, so `groundAt` rays straight through our
-- own trees (design 10.1). `places.spec` asserts the two agree, so the list cannot drift from the
-- folder it is about.
Places.FOLDER = "DrivePlaces"

-- WHERE THE TEMPLATES COME FROM, in order of preference. Both are Studio content in Karen's Forest
-- Test and both are read-only here: a template is CLONED, never moved, re-parented, scaled or
-- destroyed (rule 7).
Places.TEMPLATE_SOURCES = table.freeze({ "OurForest", "LobbyAssets.Trees", "Session" })

-- THE CLAW FRACTIONS THAT ARE NOT ZERO, measured by `tools/forest_ground.py species` on 2026-10-16
-- and recorded in `tools/forest_claws.json`. Of this world's 61 models it accepted 25 and only these
-- five carry a non-zero fraction; every other model is ZERO by the tool's own rule -- a measurement
-- that could not be trusted (the spruces' and larches' skirt branches read as a "first hit" fourteen
-- studs up) is not used, and zero just seats the model's lowest geometry on the ground.
--
-- FIVE NUMBERS AND NOT A COPY OF THE FILE, deliberately: a tool's JSON cannot be read in game, and a
-- second copy of fifty-six zeroes is fifty-six chances to drift. `places.spec` asserts the five
-- against this table; `tools/studio_mcp.py selftest` is where a check against the JSON itself would
-- go if these ever stop being five.
Places.CLAW_FRACTION = table.freeze({
	SilverBirch_Var07_LOD_0 = 0.0562,
	SilverBirch_Var10_LOD_0 = 0.0003,
	SilverBirch_Var11_LOD_0 = 0.0425,
	SilverBirch_Var12_LOD_0 = 0.0393,
	SilverBirch_Var13_LOD_0 = 0.0239,
})

-- HOW MUCH GROUND SPREAD A TREE OF THIS HEIGHT MAY BE PLANTED ACROSS, before this module refuses the
-- spot rather than seating it.
--
-- IT IS A FRACTION OF THE HEIGHT AND NOT A CONSTANT, AND THAT WAS MEASURED. `TreeGround.CLIFF_STUDS`
-- (4) is the number the RE-SEATING tool uses, where the question is *"would sinking this existing tree
-- bury it?"*; here the question is *"is this a spot to plant one at all?"*, and on this world's rolling
-- ground a flat 4 refused **776 of 2,713** candidates -- 29% of the forest, as holes. The junction
-- always goes to the LOWEST ground under the footprint, so nothing floats either way; the only thing
-- the spread costs is how much of the UPHILL root flare is buried, and a tenth of the tree's height is
-- not something an eye can see. `CLIFF_STUDS` stays the floor, so ferns and saplings keep the
-- tool's own allowance.
function Places.stepAllowance(heightStuds: number): number
	return math.max(TreeGround.CLIFF_STUDS, 0.10 * heightStuds)
end

-- A PART IS INVISIBLE AT OR ABOVE THIS TRANSPARENCY, and an invisible part must never stop a bullet.
-- `forest_ground.py`'s own number, for the same reason it needed one: *"the birches carry an
-- invisible `Basepart` pad that would otherwise define the model's bottom"*.
Places.INVISIBLE_AT = 0.95

-- ---------------------------------------------------------------- pure helpers

-- THE AXIS-ALIGNED WORLD BOX OF ONE PART, as plain numbers for `TreeGround`. The rotated size
-- projected onto the axes, which is `Lobby.Build.worldBoxOf`'s arithmetic -- restated here rather
-- than reached into, because that function is private to the lobby's owner.
function Places.boxOf(part: BasePart): TreeGround.Box
	local size = part.Size
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = part.CFrame:GetComponents()
	local half = Vector3.new(
		0.5 * (math.abs(r00) * size.X + math.abs(r01) * size.Y + math.abs(r02) * size.Z),
		0.5 * (math.abs(r10) * size.X + math.abs(r11) * size.Y + math.abs(r12) * size.Z),
		0.5 * (math.abs(r20) * size.X + math.abs(r21) * size.Y + math.abs(r22) * size.Z)
	)
	local at = part.Position
	return {
		minX = at.X - half.X,
		minY = at.Y - half.Y,
		minZ = at.Z - half.Z,
		maxX = at.X + half.X,
		maxY = at.Y + half.Y,
		maxZ = at.Z + half.Z,
	}
end

-- THE CLAW FRACTION FOR A MODEL NAME. Zero for everything the tool did not accept a number for,
-- which is the tool's own decision and not a default chosen here.
function Places.clawFor(model: string): number
	return (Places.CLAW_FRACTION :: any)[model] or 0
end

-- ---------------------------------------------------------------- the world half

-- WHICH PART IS THE TRUNK, and the footprint that matters is ITS and never the crown's. A birch's
-- crown is twenty-five studs across and its flare is eight, so a grid over the whole bounding box
-- reads the ground under the canopy, twelve studs away and down a bank -- task 196 part 3c made
-- exactly that mistake and reported zero floating trees (`tools/forest_ground.py`'s docstring).
--
-- The rule is that tool's: the part whose name contains "Trunk" (the lowest, if several), else the
-- parts whose own bottom is within `TreeGround.groundBand` of the model's lowest point, else the
-- whole model.
function Places.trunkBox(model: Model): (TreeGround.Box?, TreeGround.Box?)
	local boxes: { TreeGround.Box } = {}
	local trunk: TreeGround.Box? = nil
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < Places.INVISIBLE_AT then
			local box = Places.boxOf(part)
			table.insert(boxes, box)
			if string.find(string.lower(part.Name), "trunk", 1, true) then
				if trunk == nil or box.minY < trunk.minY then
					trunk = box
				end
			end
		end
	end
	local whole = TreeGround.bounds(boxes)
	if whole == nil then
		return nil, nil
	end
	if trunk ~= nil then
		return trunk, whole
	end
	local reaching: { TreeGround.Box } = {}
	local band = TreeGround.groundBand(whole.maxY - whole.minY)
	for _, box in ipairs(boxes) do
		if box.minY - whole.minY <= band then
			table.insert(reaching, box)
		end
	end
	return TreeGround.bounds(reaching) or whole, whole
end

-- THE TERRAIN UNDER A FOOTPRINT, on `TreeGround`'s own 5 x 5 grid (lesson L-024: *"ground height
-- must be sampled at each tree's actual footprint corners, not one point reused for the whole
-- model"*). `groundAt` is handed in, so a spec can drive this with a fake hillside and no Terrain.
function Places.groundsUnder(box: TreeGround.Box, groundAt: (number, number) -> number?): { number }
	local out: { number } = {}
	for _, point in ipairs(TreeGround.samples(box.minX, box.minZ, box.maxX, box.maxZ, 4)) do
		local y = groundAt(point.x, point.z)
		if y ~= nil then
			table.insert(out, y)
		end
	end
	return out
end

-- SHOTS MUST NOT DIE IN LEAVES (lesson L-060; task 149 lost 4 of 5 shots to foliage). Measured in
-- this world on 2026-10-17: `OurForest`'s trees already carry the right flags -- only `Trunk`
-- collides and queries, every leaf and branch is false on both -- with two exceptions this fixes,
-- and `Workspace.Session`'s trees carry none of them (every part queries).
--
-- THE RULE IS WRITTEN AGAINST WHAT THE PART IS, not against a name list: anything invisible, and
-- anything that does not collide, cannot be queried. A trunk collides, so a trunk still stops a
-- bullet -- which it must.
function Places.quieten(model: Model): number
	local changed = 0
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			if part.CanQuery and (part.Transparency >= Places.INVISIBLE_AT or not part.CanCollide) then
				part.CanQuery = false
				changed += 1
			end
			-- A PLANTED TREE IS SCENERY AND NOTHING SIMULATES IT.
			part.Anchored = true
		end
	end
	return changed
end

-- PLANT ONE. Returns the model, or nil with a reason.
--
-- THE ORDER MATTERS AND IS NOT COSMETIC: scale FIRST, then yaw and the provisional position, then
-- measure, then settle. `Model:ScaleTo` moves every part, so a tree measured before it was scaled is
-- a tree measured at the wrong size -- and the claw fraction is a fraction of HEIGHT precisely so
-- that it survives this step.
function Places.plantOne(
	item: Plan.Planting,
	template: Model,
	parent: Instance,
	groundAt: (number, number) -> number?
): (Model?, string)
	local rough = groundAt(item.x, item.z)
	if rough == nil then
		return nil, "no-ground"
	end
	local made = template:Clone()
	if item.scale ~= 1 then
		made:ScaleTo(item.scale)
	end
	-- HIGH ENOUGH THAT THE SETTLE IS ALWAYS A DROP. `TreeGround.decide` only ever sinks a tree (its
	-- own header: *"A tree that is already deep in the ground is left exactly where it is"*), so a
	-- freshly cloned tree is offered to it from above and never from below.
	made:PivotTo(CFrame.new(item.x, rough + made:GetExtentsSize().Y, item.z) * CFrame.Angles(0, item.yaw, 0))
	local trunk, whole = Places.trunkBox(made)
	if trunk == nil or whole == nil then
		made:Destroy()
		return nil, "no-geometry"
	end
	local grounds = Places.groundsUnder(trunk, groundAt)
	if #grounds == 0 then
		made:Destroy()
		return nil, "no-ground"
	end
	-- A FOOTPRINT ACROSS A STEP IS NOT PLANTED AT ALL, and that is the one place this module refuses
	-- rather than settles. `TreeGround.decide` answers "cliff" there and declines to move an EXISTING
	-- tree, because sinking it to the lowest reading would bury it to the crown on the high side.
	-- For a tree nobody has planted yet the honest answer is to plant it somewhere else -- so it is
	-- skipped and counted, never left standing in the air (standing rule E).
	if TreeGround.spread(grounds) > Places.stepAllowance(whole.maxY - trunk.minY) then
		made:Destroy()
		return nil, "cliff"
	end
	local verdict = TreeGround.decide(trunk.minY, whole.maxY, Places.clawFor(item.model), grounds)
	if verdict.move and verdict.lift ~= nil then
		made:PivotTo(made:GetPivot() + Vector3.new(0, verdict.lift, 0))
	end
	Places.quieten(made)
	made.Name = item.model
	made:SetAttribute("DrivePlaceBand", item.band)
	made.Parent = parent
	return made, verdict.reason
end

-- THE TEMPLATE FOLDERS THIS PLACE ACTUALLY HAS. Nil when none of them is here, which is the DEV
-- case and is not an error.
function Places.templates(world: Instance?): { Instance }
	local root = world or Workspace
	local out: { Instance } = {}
	for _, path in ipairs(Places.TEMPLATE_SOURCES) do
		local at: Instance? = root
		for piece in string.gmatch(path, "[^%.]+") do
			at = if at then at:FindFirstChild(piece) else nil
		end
		if at ~= nil then
			table.insert(out, at)
		end
	end
	return out
end

-- BUILD EVERY DRESSED PLACE. Returns one report line's worth of counts.
--
-- `groundAt` AND `world` ARE ARGUMENTS AND NEVER `Workspace` BY DEFAULT inside a spec's reach, which
-- is `Lobby.Field`'s discipline: *"a spec hands in a fake with a recording FillBlock, so no spec in
-- the DEV place can write DEV's terrain, ever"*.
function Places.build(groundAt: ((number, number) -> number?)?, world: Instance?, terrain: any?): { [string]: any }
	local root = world or Workspace
	-- THE GROUND READER IS HANDED IN AND THERE IS NO DEFAULT, AND THAT IS DESIGN 10.1 RATHER THAN
	-- strictness. The obvious default -- `ForestTest.groundAt` -- CAN SEE THIS MODULE'S OWN TREES: a
	-- planted trunk keeps `CanQuery = true` (it has to stop a bullet) and `plantOne` parents each clone
	-- before the next one is measured, so a tree could be planted on the trunk of the tree planted a
	-- moment earlier -- and WHICH tree would depend on the planting order, which breaks the one
	-- property this whole system rests on (the plan is a pure function of its seed). Worse, that same
	-- function is the CANOPY half of `Markers.groundFor`, where a one-stud disagreement with the
	-- terrain reader REFUSES A STAND.
	--
	-- So the boot passes `ForestTest.terrainYAt` -- Terrain only -- and this module keeps no second
	-- definition of where the ground is. The two plots hold zero non-terrain parts (BRIEF M8) and
	-- terrain answered every sample over this ground (M4), so terrain IS the ground here.
	if groundAt == nil then
		return { places = 0, planted = 0, skipped = 0, missing = 0, cliff = 0, seconds = 0, reason = "no-ground-reader" }
	end
	local reader = groundAt
	local sources = Places.templates(root)
	local existing = root:FindFirstChild(Places.FOLDER)
	if existing then
		-- ONE WRITER MEANS ONE FOLDER. A second boot in the same session rebuilds rather than
		-- doubling, and what it destroys is only ever this module's own output.
		existing:Destroy()
	end
	local report = { places = 0, planted = 0, skipped = 0, missing = 0, cliff = 0, parts = 0, paints = 0, seconds = 0 }
	if #sources == 0 then
		report.reason = "no-templates"
		return report
	end
	local started = os.clock()
	local folder = Instance.new("Folder")
	folder.Name = Places.FOLDER
	local lookup: { [string]: Model } = {}
	local function template(name: string): Model?
		local found = lookup[name]
		if found then
			return found
		end
		for _, source in ipairs(sources) do
			local child = source:FindFirstChild(name)
			if child and child:IsA("Model") then
				lookup[name] = child
				return child
			end
		end
		return nil
	end
	for _, name in ipairs(Forest.LAYOUT_ORDER) do
		local layout = Forest.layoutNamed(name)
		local plan = Plan.planFor(name)
		if layout ~= nil and plan ~= nil then
			local here = Instance.new("Folder")
			here.Name = name
			here.Parent = folder
			report.places += 1
			-- THE SURFACE FIRST, because `ReplaceMaterial` changes material and never height: painting
			-- after the trees would not move one of them, but painting first keeps the order the design
			-- states and means a failed paint cannot be mistaken for a failed planting.
			report.paints += Ground.paint(terrain, layout, plan, function(x: number)
				return Forest.roadZ(x, layout)
			end, reader)
			for _, item in ipairs(Plan.plant(layout, plan)) do
				local source = template(item.model)
				if source == nil then
					report.missing += 1
				else
					local made, reason = Places.plantOne(item, source, here, reader)
					if made ~= nil then
						report.planted += 1
					elseif reason == "cliff" then
						report.cliff += 1
					else
						report.skipped += 1
					end
				end
			end
		end
	end
	folder.Parent = root
	-- THE PART COUNT IS PRINTED AND NOT ASSUMED (design 11: *"must be printed, not assumed"*). The
	-- estimate behind the target was ~7 descendants per model; this is the number itself.
	for _, place in ipairs(folder:GetChildren()) do
		for _, thing in ipairs(place:GetDescendants()) do
			if thing:IsA("BasePart") then
				report.parts += 1
			end
		end
	end
	report.seconds = os.clock() - started
	return report
end

-- WHAT WAS PLANTED, for the boot's own line and for a live probe. Read-only.
function Places.stats(world: Instance?): { [string]: any }
	local root = world or Workspace
	local folder = root:FindFirstChild(Places.FOLDER)
	local out: { [string]: any } = { folder = folder ~= nil, total = 0 }
	if folder == nil then
		return out
	end
	for _, place in ipairs(folder:GetChildren()) do
		local n = #place:GetChildren()
		out[place.Name] = n
		out.total += n
	end
	return out
end

return Places
