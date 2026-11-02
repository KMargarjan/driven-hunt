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
-- THE BUDGETED LOOP (task 327c): it spends a frame and enforces destroy-before-plant.
local Slice = require(script:WaitForChild("Slice"))
local TreeGround = require(ReplicatedStorage:WaitForChild("TreeGround"))
local Forest = require(ReplicatedStorage:WaitForChild("ForestTest"))
-- THE GRID (task 327a): the eight drive cells' arithmetic. PURE data -- this module is the one that
-- draws it, and `Grid` knows nothing about Workspace.
local Grid = require(ReplicatedStorage:WaitForChild("Grid"))
local Flags = require(ReplicatedStorage:WaitForChild("Flags"))

local Places = {}

-- WHERE THE PLANTED WOOD LIVES: one folder, one child per place. Named for what it is, and NOT
-- `OurForest` or `Foliage` -- a reader has to be able to tell at a glance which trees a commit owns
-- and which are Karen's Studio content that rule 7 protects.
-- IT IS ALSO THE NAME `ForestTest.GROUND_IGNORE` CARRIES, so `groundAt` rays straight through our
-- own trees (design 10.1). `places.spec` asserts the two agree, so the list cannot drift from the
-- folder it is about.
Places.FOLDER = "DrivePlaces"

-- ---------------------------------------------------------------- the grid preview (task 327a)

-- WHERE THE GRID'S OWN OUTPUT LIVES, and it is a SECOND folder rather than a child of the first: the
-- four places and the eight cells are two worlds, only one of them is ever live, and
-- `docs/design/grid-map.md` section 11.3 step 2 wants the one that is NOT this world's destroyed at
-- every boot. It is also the name `ForestTest.GROUND_IGNORE` carries, so a corner stake can never be
-- mistaken for the ground.
Places.GRID_FOLDER = "GridPlaces"

-- THE FLAG THAT SHOWS IT. Born OFF (`src/shared/Flags/init.luau`); read ONCE here, at this module's
-- boundary, and passed inward as a boolean -- the only permitted shape (CLAUDE.md, "Feature flags").
Places.GRID_FLAG = "GRID_PREVIEW"

-- A CORNER STAKE: a tall thin orange pillar at each of the eight cells' four corners, 32 in all.
--
-- `CanCollide` AND `CanQuery` ARE BOTH FALSE, and that is not tidiness: a queryable stake standing
-- inside the footprint would answer `ForestTest.groundAt` as "the ground" and would stop a bullet.
-- `Neon` so it reads from the far end of a 1070-stud cell.
Places.STAKE = table.freeze({
	sizeStuds = Vector3.new(3, 60, 3),
	colour = Color3.fromRGB(255, 132, 0),
	material = Enum.Material.Neon,
	-- HOW MANY GO IN BEFORE THE FRAME IS GIVEN BACK. 32 parts is nothing, but the slice is the
	-- pattern this system uses everywhere and a later task plants 2,400 models through it.
	perStep = 8,
})

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
--
-- ...AND THAT RULE WAS NOT ENOUGH, WHICH TASK 260 MEASURED WITH A CONTROL. Two casts in the Forest
-- Test on 2026-10-25 (`driven-hunt-runs/260-why.luau`, read-only), each an Include-filtered ray at
-- ONE named part:
--     `OurForest.SilverBirch_Var11_LOD_0.Branch.001`  CanQuery=false, CanCollide=TRUE  -> **HIT**
--     `OurForest.SM_AspenTree_Var02.SM_Leaves`        CanQuery=false, CanCollide=false -> no hit
-- **SO `CanQuery = false` DOES NOT EXEMPT A PART FROM A RAYCAST WHILE IT STILL COLLIDES** -- not in
-- the Studio this game is built on, whatever the property's name suggests. The clause above only
-- ever cleared `CanQuery` on parts that were ALREADY not colliding, which is exactly the set for
-- which it changed nothing, and the 127 colliding `Branch` parts in this world went on stopping
-- bullets. That is why L-060 recurred in task 258a(f) with an aim ray dying on a `Branch` 3-7 studs
-- in front of two boars at 79 m, and it is the whole reason this function needed a second arm.
--
-- SO FOLIAGE LOSES BOTH PROPERTIES (the Director's decision, 2026-10-25): *"real life: thin foliage
-- does not stop a rifle bullet or a slug, and an invisible stop frustrates"*. Trunks and the ground
-- still stop shots, which is the other half of the same sentence.
--
-- AND THIS ARM IS A NAME LIST, WHICH THE PARAGRAPH ABOVE SAYS THE RULE IS NOT -- so here is the
-- reason, written down rather than quietly contradicted. A leaf that is VISIBLE and COLLIDES is
-- indistinguishable from a trunk by its properties: that is the whole state the measurement found.
-- The only signal left is the artist's own name, and in this world it is a reliable one -- the
-- queryable foliage is 623 parts across five names (`OuterLeaves`, `Bush`, `Bush1`, `Bush3`,
-- `Bush4`) and the colliding branches 127 across three (`Branch`, `Branch.001`, `Branch.002`),
-- against trunks named `Trunk`, `SM_Trunk` and `CollidePart`. `places.spec` asserts that no name in
-- `FOLIAGE_WORDS` matches any of those three.
Places.FOLIAGE_WORDS = table.freeze({
	"leaf",
	"leaves",
	"branch",
	"twig",
	"frond",
	"fern",
	"needle",
	"canopy",
	"crown",
	"bush",
	"shrub",
})

-- IS THIS PART FOLIAGE BY NAME? Case-insensitive substring, so `SM_Leaves`, `OuterLeaves`,
-- `Branch.002` and `Bush4` all answer true and `Trunk`, `SM_Trunk` and `CollidePart` all answer
-- false. One definition, so the sweep and the spec cannot disagree about what a leaf is.
function Places.isFoliageName(name: string): boolean
	local lower = string.lower(name)
	for _, word in ipairs(Places.FOLIAGE_WORDS) do
		if string.find(lower, word, 1, true) then
			return true
		end
	end
	return false
end

-- THE ONE RULE, APPLIED TO ANY TREE ANYWHERE: a leaf or a branch stops nothing. Returns how many
-- parts it changed, so a caller can report "0" and mean it.
--
-- IT TOUCHES NOTHING ELSE. Not `Anchored`, not `Transparency`, not a material, not a position --
-- which is what lets it be run over STANDING STUDIO CONTENT (`Workspace.OurForest`,
-- `Workspace.Session`) as well as over a planted clone. `Places.quieten` is the planting path and
-- calls this first.
function Places.unblockFoliage(root: Instance): number
	local changed = 0
	local function apply(part: BasePart)
		local foliage = Places.isFoliageName(part.Name)
		local invisible = part.Transparency >= Places.INVISIBLE_AT
		-- BOTH PROPERTIES, BECAUSE THE MEASUREMENT SAYS ONE IS NOT ENOUGH (see the header): a ray
		-- stops on a colliding part whether or not it may be queried.
		if foliage then
			if part.CanQuery then
				part.CanQuery = false
				changed += 1
			end
			if part.CanCollide then
				part.CanCollide = false
				changed += 1
			end
		elseif part.CanQuery and (invisible or not part.CanCollide) then
			-- THE ORIGINAL PROPERTY RULE, UNCHANGED, for everything that is not named foliage: an
			-- invisible part, or one a player walks through, may not stop a bullet either.
			part.CanQuery = false
			changed += 1
		end
	end
	if root:IsA("BasePart") then
		apply(root)
	end
	for _, part in ipairs(root:GetDescendants()) do
		if part:IsA("BasePart") then
			apply(part)
		end
	end
	return changed
end

-- EVERY FOLDER OF TREES IN THIS WORLD, AND "EVERY" IS THE WHOLE POINT (task 260). `Places.templates`
-- resolves each `TEMPLATE_SOURCES` entry with `FindFirstChild`, which answers ONE child -- and
-- MEASURED in the Forest Test on 2026-10-25 this place has **two folders both called `Session`**
-- (`Workspace` children: `... OurForest Session Session`). The first sweep took 623 queryable
-- foliage parts down to 41, and all 41 were in the second one: 26 `OuterLeaves` and 15 bushes under
-- `Mesh Tree` / `Mesh TreeV`. A name lookup cannot see a duplicate, so this walks the children.
--
-- IT MATCHES THE FIRST SEGMENT of each source path, so `LobbyAssets.Trees` is reached through
-- `LobbyAssets` -- sweeping the whole of that folder rather than just its `Trees` child, which is
-- what the rule wants anyway: a leaf stops nothing wherever it stands.
function Places.foliageRoots(root: Instance): { Instance }
	local wanted: { [string]: boolean } = {}
	for _, path in ipairs(Places.TEMPLATE_SOURCES) do
		wanted[string.split(path, ".")[1]] = true
	end
	local found: { Instance } = {}
	for _, child in ipairs(root:GetChildren()) do
		if wanted[child.Name] then
			table.insert(found, child)
		end
	end
	return found
end

function Places.quieten(model: Model): number
	local changed = Places.unblockFoliage(model)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			-- A PLANTED TREE IS SCENERY AND NOTHING SIMULATES IT. It is this function's own line and
			-- NOT `unblockFoliage`'s, because that one is run over standing Studio content too and
			-- anchoring somebody else's parts is not what it was asked to do.
			part.Anchored = true
		end
	end
	return changed
end

-- HOW FAR THE JUNCTION STANDS ABOVE THE LOWEST GROUND UNDER THE TRUNK'S OWN FOOTPRINT. Positive is
-- daylight. `nil` when the model has no geometry or the world cannot answer under it. It exists so a
-- SPEC can re-measure a settled tree off the model instead of off the lift that was applied to it
-- (lessons L-028 and L-086); nothing in `src/` reads it.
function Places.junctionGap(model: Model, groundAt: (number, number) -> number?): number?
	local trunk, whole = Places.trunkBox(model)
	if trunk == nil or whole == nil then
		return nil
	end
	local grounds = Places.groundsUnder(trunk, groundAt)
	if #grounds == 0 then
		return nil
	end
	local lowest = math.huge
	for _, y in ipairs(grounds) do
		lowest = math.min(lowest, y)
	end
	return TreeGround.junctionY(trunk.minY, whole.maxY, Places.clawFor(model.Name)) - lowest
end

-- THE STANDING WOOD GETS THE RULE TOO, AT RUN TIME (task 326). Karen, 2026-11-01: *"also fix broken
-- trees all terai some trees is high in air"*. Four models in `Workspace.Session` -- the bought map's
-- own foliage, saved place content no commit can move -- hang 29 to 65 studs above the terrain.
-- `tools/forest_ground.py` can re-seat that content in Edit, but a tool run is not a fix that ships;
-- this is the same arithmetic (`TreeGround.decide`), run by the module that already sweeps these
-- folders at boot, so the place file is untouched and deleting this function puts the trees back.
--
-- IT ONLY EVER LOWERS A TREE: `decide` answers `seated` for anything already in the ground and
-- `cliff` for a footprint across a step, and neither moves. Returns how many it lowered.
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
		-- `Model:ScaleTo` IS ABSOLUTE AND `item.scale` IS RELATIVE ("1 is the template's own size").
		-- 52 of this world's 61 templates stand at a `Scale` that is not 1 (the birches at 0.032-0.054,
		-- the larches at 1.4-2.1), so `ScaleTo(0.95)` grew a birch by 25x: task 326 measured 125 models
		-- whose PART CENTRES span over 300 studs (worst 1394) -- 329 by the census's oriented boxes,
		-- worst 2260 -- and their trunks 1800 studs above the ground.
		made:ScaleTo(made:GetScale() * item.scale)
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
	--
	-- ONE ALLOWANCE, ASKED ONCE AND HANDED TO THE VERDICT. Until task 326 the pre-check used
	-- `stepAllowance` and `TreeGround.decide` re-checked with its own `CLIFF_STUDS` (4): a footprint
	-- between the two answered "cliff" from the verdict, `move` was false, and the clone stayed exactly
	-- where `PivotTo` had put it -- one whole tree-height above the ground. 536 of the 646 floating
	-- trees task 326 counted in her place were that case.
	local allowance = Places.stepAllowance(whole.maxY - trunk.minY)
	if TreeGround.spread(grounds) > allowance then
		made:Destroy()
		return nil, "cliff"
	end
	local verdict = TreeGround.decide(trunk.minY, whole.maxY, Places.clawFor(item.model), grounds, allowance)
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

-- ---------------------------------------------------------------- the grid preview, drawn

-- IS THE PREVIEW ON? **THE ONE PLACE THE FLAG IS READ**, so every other function here takes a
-- boolean and both of its states are reachable from a pure spec.
function Places.gridPreviewEnabled(): boolean
	return Flags.isOn(Places.GRID_FLAG)
end

-- THE FOUR CORNERS OF EVERY CELL, as a flat list. PURE -- no world, no terrain. The name carries the
-- cell id and the corner, so a frame of a stake says which cell it belongs to.
function Places.gridStakes(): { { name: string, x: number, z: number } }
	local out: { { name: string, x: number, z: number } } = {}
	for _, id in ipairs(Grid.cellIds()) do
		local box = Grid.boundsOf(id)
		-- NORTH IS THE LARGER z in this world (`ForestTest.EXIT_SOUTH_STUDS`: a boar is gone to the
		-- south), so NW/NE are at maxZ.
		for _, corner in ipairs({
			{ "SW", box.minX, box.minZ },
			{ "SE", box.maxX, box.minZ },
			{ "NW", box.minX, box.maxZ },
			{ "NE", box.maxX, box.maxZ },
		}) do
			table.insert(out, {
				name = string.format("Stake_%s_%s", id, corner[1] :: string),
				x = corner[2] :: number,
				z = corner[3] :: number,
			})
		end
	end
	return out
end

-- STAKE THE EIGHT CELLS' CORNERS. Returns how many went in and how many had no ground under them.
--
-- `enabled`, `folder` AND `terrainYAt` ARE ALL ARGUMENTS: a spec drives this into a fake folder with
-- a fake hillside, and `enabled = false` parents nothing at all. `breathe` is the slice.
function Places.stakeGrid(
	folder: Instance?,
	terrainYAt: (number, number) -> number?,
	enabled: boolean,
	breathe: (() -> ())?
): (number, number)
	if not enabled or folder == nil then
		return 0, 0
	end
	local made, missing, since = 0, 0, 0
	for _, stake in ipairs(Places.gridStakes()) do
		local y = terrainYAt(stake.x, stake.z)
		if y == nil then
			missing += 1
		else
			local part = Instance.new("Part")
			part.Name = stake.name
			part.Size = Places.STAKE.sizeStuds
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Material = Places.STAKE.material
			part.Color = Places.STAKE.colour
			part.Position = Vector3.new(stake.x, y + Places.STAKE.sizeStuds.Y / 2, stake.z)
			part.Parent = folder
			made += 1
			since += 1
			if breathe ~= nil and since >= Places.STAKE.perStep then
				since = 0
				breathe()
			end
		end
	end
	return made, missing
end

-- WHICH CHILDREN OF `GridPlaces` ARE A CELL'S WOOD. One folder per cell id, beside the corner stakes
-- (which are BaseParts named `Stake_*`), so a reader can see at a glance which cell is standing and
-- the dress can destroy the previous one without touching anything else.
function Places.cellWoodFolders(gridFolder: Instance?): { Instance }
	local out: { Instance } = {}
	if gridFolder == nil then
		return out
	end
	for _, child in ipairs(gridFolder:GetChildren()) do
		if child:IsA("Folder") and Grid.cellOf(child.Name) ~= nil then
			table.insert(out, child)
		end
	end
	return out
end

-- DRESS ONE CELL: destroy whatever cell is standing, then plant this one, both through `Slice` and
-- both in `Slice.BUDGET_MS` bites. Returns one report line's worth of counts.
--
-- THE ORDER IS THE SLICE'S AND NOT THIS FUNCTION'S (`Slice.ORDER`): both jobs are queued and the
-- queue runs every destroy first, so the peak part count is one cell's. The new folder is created by
-- the FIRST PLANTED ITEM, after which the old folders are already empty -- which is the same fact
-- said in code rather than in a comment.
--
-- EVERY MOVING PART IS AN ARGUMENT: the folder, the ground reader, the template lookup, the yield and
-- the clock. A spec drives this into a fake folder on a fake hillside with no Terrain and no yield.
function Places.dressCell(
	cellId: string,
	gridFolder: Instance?,
	groundAt: (number, number) -> number?,
	template: (string) -> Model?,
	breathe: (() -> ())?,
	clock: (() -> number)?
): { [string]: any }
	local tick = clock or os.clock
	local report = {
		cell = cellId,
		planted = 0,
		skipped = 0,
		missing = 0,
		cliff = 0,
		destroyed = 0,
		parts = 0,
		steps = 0,
		seconds = 0,
		stepMsAvg = 0,
		stepMsMax = 0,
		overBudgetStarts = 0,
		wanted = 0,
		capacity = 0,
	}
	if gridFolder == nil or Grid.cellOf(cellId) == nil then
		report.reason = "no-cell"
		return report
	end
	Slice.reset()
	local old = Places.cellWoodFolders(gridFolder)
	local dying: { Instance } = {}
	for _, folder in ipairs(old) do
		for _, child in ipairs(folder:GetChildren()) do
			table.insert(dying, child)
		end
	end
	-- NEAREST THE HUNTER LINE FIRST. The line is the cell's MAIN road (`Grid.layoutFor`), which is
	-- the layout `ForestTest.roadZ` answers for.
	local layout = Grid.layoutFor(cellId)
	local wanted = Slice.order(Plan.plantCell(cellId), layout)
	report.wanted = #wanted
	report.capacity = Plan.cellCapacity(cellId)

	local here: Instance? = nil
	local function ensureFolder(): Instance
		if here == nil then
			-- THE OLD SHELLS GO NOW, and they are empty: the destroy job ran first.
			for _, folder in ipairs(old) do
				folder:Destroy()
			end
			local made = Instance.new("Folder")
			made.Name = cellId
			made.Parent = gridFolder
			here = made
		end
		return here :: Instance
	end

	Slice.begin("plant", wanted, {
		clock = tick,
		work = function(item)
			local source = template(item.model)
			if source == nil then
				report.missing += 1
				return
			end
			local made, reason = Places.plantOne(item, source, ensureFolder(), groundAt)
			if made ~= nil then
				report.planted += 1
			elseif reason == "cliff" then
				report.cliff += 1
			else
				report.skipped += 1
			end
		end,
	})
	Slice.begin("destroy", dying, {
		clock = tick,
		work = function(item)
			item:Destroy()
		end,
	})

	local done = false
	-- A HARD STEP CEILING SO A BROKEN `work` CANNOT SPIN FOR EVER: every step does at least one item,
	-- so the queue cannot need more steps than it has items.
	local ceiling = #wanted + #dying + 2
	local steps = 0
	while not done and steps < ceiling do
		local _, finished = Slice.step(tick())
		done = finished
		steps += 1
		if breathe ~= nil and not done then
			breathe()
		end
	end
	-- NOTHING WAS PLANTED (no templates in this world): the old shells still have to go.
	for _, folder in ipairs(old) do
		if folder.Parent ~= nil then
			folder:Destroy()
		end
	end
	local stats = Slice.stats()
	report.destroyed = stats.destroyed
	report.steps = stats.steps
	report.stepMsAvg = stats.stepMsAvg
	report.stepMsMax = stats.stepMsMax
	report.overBudgetStarts = stats.overBudgetStarts
	report.seconds = stats.seconds
	if here ~= nil then
		for _, thing in ipairs((here :: Instance):GetDescendants()) do
			if thing:IsA("BasePart") then
				report.parts += 1
			end
		end
	end
	return report
end

-- BUILD EVERY DRESSED PLACE. Returns one report line's worth of counts.
--
-- `groundAt` AND `world` ARE ARGUMENTS AND NEVER `Workspace` BY DEFAULT inside a spec's reach, which
-- is `Lobby.Field`'s discipline: *"a spec hands in a fake with a recording FillBlock, so no spec in
-- the DEV place can write DEV's terrain, ever"*.
function Places.build(
	groundAt: ((number, number) -> number?)?,
	world: Instance?,
	terrain: any?,
	-- THE GRID PREVIEW, BY PARAMETER. nil reads the flag at this module's boundary
	-- (`Places.gridPreviewEnabled`); a spec passes true or false and never touches the flag.
	gridPreview: boolean?,
	-- THE SLICE. The boot hands `task.wait`; a spec hands nil, and nothing yields.
	breathe: (() -> ())?
): { [string]: any }
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
		return {
			places = 0,
			planted = 0,
			skipped = 0,
			missing = 0,
			cliff = 0,
			seconds = 0,
			gridPaints = 0,
			gridStakes = 0,
			gridMissing = 0,
			gridSeconds = 0,
			reason = "no-ground-reader",
		}
	end
	local reader = groundAt
	local sources = Places.templates(root)
	local existing = root:FindFirstChild(Places.FOLDER)
	if existing then
		-- ONE WRITER MEANS ONE FOLDER. A second boot in the same session rebuilds rather than
		-- doubling, and what it destroys is only ever this module's own output.
		existing:Destroy()
	end
	local report = {
		places = 0,
		planted = 0,
		skipped = 0,
		missing = 0,
		cliff = 0,
		parts = 0,
		paints = 0,
		unblocked = 0,
		seconds = 0,
		gridPaints = 0,
		gridStakes = 0,
		gridMissing = 0,
		gridSeconds = 0,
	}

	-- ------------------------------------------------ THE GRID PREVIEW (task 327a), FIRST
	--
	-- **BEFORE THE TEMPLATE CHECK, AND THAT IS THE POINT:** the grid's roads and corner stakes need
	-- no tree template at all, so they must not be skipped in a world that has none -- which is
	-- every DEV spec run.
	--
	-- **THE OTHER WORLD'S FOLDER IS DESTROYED WHATEVER THE FLAG SAYS** (design 11.3 step 2): the
	-- grid's parts must not be left standing in a world that has never heard of them, and task 79
	-- measured what that costs in the other direction (both worlds tag with the same strings).
	local previewOn = if gridPreview == nil then Places.gridPreviewEnabled() else gridPreview
	local priorGrid = root:FindFirstChild(Places.GRID_FOLDER)
	if priorGrid then
		priorGrid:Destroy()
	end
	local gridStarted = os.clock()
	-- THE SURFACE IS THE `track` PLACE'S, which is the one Karen's reference frames demand: an
	-- 18-stud `Ground` strip (design 4.1). The ruts are NOT painted on a grid road -- see
	-- `Ground.ROAD_CHUNK_STUDS` for the call arithmetic that decides it.
	report.gridPaints = Ground.paintRoads(terrain, Grid.roads(), Plan.surfaceFor("track"), reader, previewOn, breathe)
	local gridFolder: Instance? = nil
	if previewOn then
		local folder = Instance.new("Folder")
		folder.Name = Places.GRID_FOLDER
		local made, missing = Places.stakeGrid(folder, reader, true, breathe)
		report.gridStakes, report.gridMissing = made, missing
		folder.Parent = root
		gridFolder = folder
	end
	report.gridSeconds = os.clock() - gridStarted

	if #sources == 0 then
		report.reason = "no-templates"
		return report
	end
	local started = os.clock()
	-- THE STANDING TREES GET THE RULE TOO (task 260), and they are the ones that mattered. Karen's
	-- wood is Studio content: `Workspace.OurForest` and `Workspace.Session` STAND in the place and
	-- are also where this module's templates are copied FROM -- so one sweep over each source fixes
	-- the trees she walks past AND every clone planted from them afterwards.
	--
	-- MEASURED BEFORE THE SWEEP EXISTED (`driven-hunt-runs/260-foliage.luau`): 623 queryable
	-- foliage parts in `Session` (357 `OuterLeaves` and 266 bushes) plus 127 COLLIDING `Branch`
	-- parts in `OurForest`, which stopped rays despite `CanQuery = false` -- see
	-- `Places.unblockFoliage`'s header for the control that proved it. DEV has neither folder, so
	-- this is a no-op there and `report.unblocked` reads 0.
	for _, source in ipairs(Places.foliageRoots(root)) do
		report.unblocked += Places.unblockFoliage(source)
	end
	-- ...AND THE FLOATING ONES ARE PUT BACK ON THE GROUND (task 326). A SEPARATE LOOP OVER A SEPARATE
	-- LIST, because the two sweeps are allowed to touch different things: `unblockFoliage` only clears
	-- `CanQuery` on leaves and may run over the lodge's templates harmlessly, while this one MOVES what
	-- it touches and must never see a building.
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
		-- THE SURFACE IS ASKED FOR SEPARATELY FROM THE PLANTING, and `road` is why: it keeps task
		-- 179's wood exactly (BRIEF decision 3) so it has no planting plan at all, but it is the place
		-- NAMED for a road and 29 of its 65 samples were grass. Painting and planting are two
		-- questions and this loop asks them separately.
		--
		-- THE SURFACE FIRST, because `ReplaceMaterial` changes material and never height: painting
		-- after the trees would not move one of them, but painting first means a failed paint cannot
		-- be mistaken for a failed planting.
		if layout ~= nil then
			report.paints += Ground.paint(terrain, layout, Plan.surfaceFor(name), function(x: number)
				return Forest.roadZ(x, layout)
			end, reader)
		end
		if layout ~= nil and plan ~= nil then
			local here = Instance.new("Folder")
			here.Name = name
			here.Parent = folder
			report.places += 1
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
	-- ------------------------------------------------ THE PREVIEW CELL'S WOOD (task 327c)
	--
	-- **AFTER THE TEMPLATE LOOKUP EXISTS AND NOT IN THE BLOCK ABOVE:** the roads and the stakes need
	-- no template, so they are built in a world that has none; a cell's wood is 2,400 clones of this
	-- world's own trees and there is nothing to clone in DEV. So the preview stakes eight cells and
	-- dresses ONE -- `Grid.PREVIEW_CELL`, which is C1 (task 327b: the cell with the most to show).
	-- Task 327d replaces this with the per-drive dress at the `Scoring -> Assigning` edge.
	if previewOn and gridFolder ~= nil then
		report.gridWood = Places.dressCell(Grid.PREVIEW_CELL, gridFolder, reader, template, breathe, nil)
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
