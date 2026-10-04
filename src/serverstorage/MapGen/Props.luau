--!strict
-- MapGen.Props: THE ONLY WRITER OF `Workspace.DrivenHuntMap.Props`. It writes no Terrain and places
-- no marker, and it is the only module in the map that turns an asset id into an Instance.
--
-- EVERY STEP IS IDEMPOTENT: each call destroys its own folder and rebuilds it, so re-running a
-- failed step does not leave a second wood behind.
--
-- IT GOES THROUGH `ServerStorage.Assets.Loader` AND NOT THROUGH AN INSERT OF ITS OWN (design, "`MapGen.Props`
-- moves onto `Assets.Loader`"). That closes TASKS.md row 74a(a): there is now ONE id table in the
-- repo and one seam that turns an id into an Instance. The Loader already inserts a `kind = "model"`
-- template, REFUSES one containing a script rather than stripping it, checks the arrived mesh's
-- aspect against the row's measured `naturalSizeStuds`, bounds the wait, adopts a late arrival, and
-- answers nil for "wear the grey box" -- all of which this file used to half-do.
--
-- NO TEMPLATE EVER OUTLIVES THE RUN, and that is not tidiness. `ServerStorage` and
-- `ReplicatedStorage` are fully Rojo-owned with `$ignoreUnknownInstances: false`, so a template
-- parked in either is DELETED at Karen's next Connect (CLAUDE.md). `Loader.setCacheParent` points
-- the cache at a folder under the MAP ROOT for the length of one step, and `Loader.clear()` destroys
-- only what that state created -- so an edit-time generator run can neither reach nor leave a
-- template a live server preloaded.
--
--   InsertService:LoadAsset https://create.roblox.com/docs/reference/engine/classes/InsertService
--   Model:ScaleTo           https://create.roblox.com/docs/reference/engine/classes/Model#ScaleTo
--   MeshPart                https://create.roblox.com/docs/reference/engine/classes/MeshPart
--
-- Design: docs/design/map-generator.md, "Props", "A tree is a mesh plus an invisible trunk collider"
-- and "How the trees get in"
local ServerStorage = game:GetService("ServerStorage")

local Assets = require(ServerStorage:WaitForChild("Assets"))
local Loader = require(ServerStorage.Assets:WaitForChild("Loader"))

local Height = require(script.Parent:WaitForChild("Height"))
local Layout = require(script.Parent:WaitForChild("Layout"))
local Scatter = require(script.Parent:WaitForChild("Scatter"))

local Props = {}

Props.ASSETS_FOLDER = "Assets"

-- The attributes every placed tree carries, naming the `Config.SPECIES` row, the age class and the
-- mesh tier it was built from. Constants, read by the spec, so a rename cannot make a spec pass by
-- looking for an attribute nothing writes.
--
-- WHAT WAS PLANTED, ON THE THING THAT WAS PLANTED (audit-005 must-fix 2). Until these existed,
-- every species claim in the repo was a claim about `Scatter.speciesAt` -- a pure function -- and
-- nothing compared it against the wood in the world; a monoculture built from one template passed
-- all of them. `Digest.of` hashes name, className, Position, Size and tags, so an attribute cannot
-- change a map's digest.
Props.SPECIES_ATTRIBUTE = "Species"
Props.AGE_ATTRIBUTE = "Age"
Props.TIER_ATTRIBUTE = "Tier"

-- The map root's Props folder, created on demand. Props is its only writer, so it is also the only
-- module that brings it into existence.
local function propsFolder(root: Instance): Folder
	local existing = root:FindFirstChild("Props")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local made = Instance.new("Folder")
	made.Name = "Props"
	made.Parent = root
	return made
end

-- `fresh` defaults to TRUE: a step rebuilds its folder rather than adding to it, which is what
-- makes re-running a step idempotent. THE LAYERS BUILT IN SUB-BLOCKS ARE THE EXCEPTION: the first
-- sub-block clears and the rest append -- and the first build of that shape ended with only the
-- last sub-block in the world, because every step wiped the one before it.
local function folder(parent: Instance, name: string, fresh: boolean?): Folder
	local existing = parent:FindFirstChild(name)
	if existing and fresh ~= false then
		existing:Destroy()
	elseif existing then
		return existing :: Folder
	end
	local made = Instance.new("Folder")
	made.Name = name
	made.Parent = parent
	return made
end

local function part(
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): Part
	local made = Instance.new("Part")
	made.Name = name
	made.Size = size
	made.Position = position
	made.Anchored = true
	made.Color = color
	made.Material = material
	made.TopSurface = Enum.SurfaceType.Smooth
	made.BottomSurface = Enum.SurfaceType.Smooth
	made.Parent = parent
	return made
end

-- A SLUG PASSES THROUGH ANYTHING A PLAYER WALKS THROUGH, applied to a whole layer at once rather
-- than remembered per piece (Task 66 review note 1, audit-005). Before this, `part()` left
-- `CanQuery` at its default `true` and only `CanCollide` was decided, which is the "two correct
-- pieces of code disagreeing" shape: one of them stopped the player and the other stopped the
-- bullet, and the grey-box log pile 20 studs downrange of post 7 absorbed slugs a player could walk
-- straight through.
local function sceneryOnly(instance: Instance)
	local function apply(candidate: Instance)
		if candidate:IsA("BasePart") then
			candidate.CanCollide = false
			candidate.CanQuery = false
		end
	end
	apply(instance)
	for _, descendant in ipairs(instance:GetDescendants()) do
		apply(descendant)
	end
end

-- ---------------------------------------------------------------- the asset seam

local function assetsFolder(root: Instance): Folder
	local existing = root:FindFirstChild(Props.ASSETS_FOLDER)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local made = Instance.new("Folder")
	made.Name = Props.ASSETS_FOLDER
	made.Parent = root
	return made
end

-- EVERY KEY THE ACTIVE BLOCK'S WOOD CAN ASK FOR, so one `preload` covers a step instead of a
-- network call per tree. Derived from `Config.SPECIES` -- nothing here spells a key.
function Props.treeKeys(config): { string }
	local seen, out = {}, {}
	for _, name in ipairs(config.SPECIES_ORDER) do
		local row = config.SPECIES[name]
		for _, tier in ipairs({ "mature", "young", "veteran", "backdrop" }) do
			for _, key in ipairs(row.keys[tier] or {}) do
				if not seen[key] then
					seen[key] = true
					table.insert(out, key)
				end
			end
		end
	end
	return out
end

-- ONE STEP'S WHOLE DEALING WITH THE LOADER, in one place, so no step can forget the teardown.
--
-- `Loader.setState(Loader.newState())` borrows: production's own state is handed back at the end,
-- untouched, whatever happened in between -- so an edit-time run cannot destroy a template a live
-- server preloaded, and `Loader.clear()` destroys only what THIS state created.
function Props.withLoader<T>(root: Instance, keys: { string }, body: () -> T): (T, { any })
	local live = Loader.setState(Loader.newState())
	Loader.setCacheParent(assetsFolder(root))
	local reports = Loader.preload(keys)
	local ok, result = pcall(body)
	Loader.clear()
	Loader.setState(live)
	local cache = root:FindFirstChild(Props.ASSETS_FOLDER)
	if cache then
		cache:Destroy() -- no template outlives the run, and neither does the folder it sat in
	end
	if not ok then
		error(result, 0)
	end
	return result :: T, reports
end

-- The reports a `preload` produced, as one short line per key that did NOT load, so a step's message
-- names what is missing instead of being silent about it.
function Props.loadFindings(reports: { any }): { string }
	local out: { string } = {}
	for _, report in ipairs(reports) do
		if not report.ok then
			table.insert(out, string.format("%s: %s", report.key, tostring(report.reason)))
		end
	end
	return out
end

-- ---------------------------------------------------------------- a tree

-- THE TREE'S OWN GEOMETRY, from its species row and its age class. One place, so the proxy, the
-- mesh scale and the trunk collider cannot disagree about how tall this tree is.
function Props.treeGeometry(config, species: string, age: string)
	local row = config.SPECIES[species]
	local scale = config.AGE[age] or config.AGE.mature
	local height = row.heightStuds * scale.heightScale
	local trunk = row.trunkStuds * scale.trunkScale
	return {
		row = row,
		height = height,
		trunkStuds = trunk,
		boleStuds = height * row.boleFraction,
		crownStuds = row.crownStuds * scale.crownScale,
	}
end

-- ONE TREE: A MESH PLUS AN INVISIBLE TRUNK COLLIDER, and this is the load-bearing shape of the whole
-- revision (design, "A tree is a mesh plus an invisible trunk collider").
--
-- A Roblox raycast and a character's collision both use a part's COLLISION GEOMETRY, not its render
-- mesh. For a whole-tree MeshPart that means one of three bad answers: `CollisionFidelity = Box` (a
-- 34 x 78 x 34 box -- shots stop in mid-air and the navmesh sees a wall), `Default` (a convex hull,
-- the same but rounded), or `PreciseConvexDecomposition` (expensive and still a canopy that eats
-- shots). And `Match.Body.tiePointFor` takes its stand-off radius from
-- `math.max(tree.Size.X, tree.Size.Z)/2`, which on a whole-tree MeshPart is the CROWN radius -- it
-- would tie a punished shooter 17 studs from the tree.
--
-- So the mesh is visuals only and a separate `Trunk` Part is the physics and the query target, and
-- it is the Model's PrimaryPart. That keeps every existing reader correct with no change:
-- `Props.trunks` returns `model.PrimaryPart`, `Markers.tagTieTrees` tags it, `Body.anchorFor` finds
-- it, `Body.tiePointFor` measures a 2-stud trunk instead of a 34-stud crown, and
-- `MapGen.reachability` paths past 2-stud obstacles.
--
-- THE CONSEQUENCE, STATED PLAINLY: A SHOT PASSES THROUGH LEAVES. Trunks stop shot; crowns do not.
-- That is the opposite of v3's proxy (whose crown was queryable) and it is deliberate -- an
-- invisible convex blob that swallows a slug near a tree is unexplainable on screen, which is this
-- project's named failure. It is Karen's to overturn, and overturning it costs one `CanQuery` and
-- one `CollisionFidelity`.
--
-- Returns true when it placed a PROXY, so a caller can report what was actually proxied.
function Props.placeTree(
	parent: Instance,
	name: string,
	tree,
	y: number,
	config,
	template: Instance?,
	row: any?
): boolean
	local geometry = Props.treeGeometry(config, tree.species, tree.age)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	model:SetAttribute(Props.SPECIES_ATTRIBUTE, tree.species)
	model:SetAttribute(Props.AGE_ATTRIBUTE, tree.age)
	model:SetAttribute(Props.TIER_ATTRIBUTE, tree.tier)

	-- THE TRUNK COLLIDER, always, mesh or no mesh: it is the one part the game interacts with.
	local trunkSize = Vector3.new(geometry.trunkStuds, geometry.boleStuds, geometry.trunkStuds)
	local stem = part(
		"Trunk",
		trunkSize,
		Vector3.new(tree.x, y + geometry.boleStuds / 2, tree.z),
		geometry.row.trunkColor,
		Enum.Material.Wood,
		model
	)
	stem.CanCollide = true
	stem.CanQuery = true
	stem.CastShadow = false
	model.PrimaryPart = stem

	if template ~= nil then
		-- InsertService:LoadAsset returns a container Model; the asset itself is its first child.
		local source = template:GetChildren()[1] or template
		local clone = source:Clone()
		clone.Name = "Mesh"
		-- THE TRUNK IS INVISIBLE UNDER A MESH. It is still the collider and the query target; what
		-- a player sees is the mesh.
		stem.Transparency = 1
		if clone:IsA("Model") then
			-- 1. THE ROTATION CORRECTION FIRST. Two of Karen's seven oaks were published LYING DOWN
			--    -- measured 2026-10-04: Forest_Var02's and Var03's bounding boxes are 82 and 78
			--    studs along Z and 35 and 25 along Y. The row carries the correction, because it is
			--    a fact about ONE upload.
			local rotation = (row and row.rotationDeg) or Vector3.zero
			clone:PivotTo(CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z)))
			-- 2. UNIFORM SCALE, so the HEIGHT is the species' own and the mesh's proportions are its
			--    own. Writing a non-uniform Size would squash the tree, and a squashed tree measures
			--    perfectly (the same argument `ServerStorage.Assets` makes about the gun).
			local _, natural = clone:GetBoundingBox()
			if natural.Y > 0 then
				clone:ScaleTo(geometry.height / natural.Y)
			end
			-- 3. THEN STAND IT ON THE GROUND. The bounding box is recomputed AFTER the rotation and
			--    the scale, so the base lands at `y` whatever the mesh's own pivot was -- a tree
			--    floating a stud above the litter is the thing a screenshot catches and a number
			--    does not.
			local box, size = clone:GetBoundingBox()
			local centre = box.Position
			clone:PivotTo(
				clone:GetPivot() + Vector3.new(tree.x - centre.X, (y + size.Y / 2) - centre.Y, tree.z - centre.Z)
			)
			-- A yaw of its own, from its own stream, so seven meshes do not all face one way.
			local yaw = Scatter.pointKey(tree.x, tree.z, 1, Scatter.STREAM.rotation) * 360
			local pivot = clone:GetPivot()
			clone:PivotTo(CFrame.new(pivot.Position) * CFrame.Angles(0, math.rad(yaw), 0) * (pivot - pivot.Position))
		end
		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
			if descendant:IsA("MeshPart") then
				local mesh = descendant :: MeshPart
				-- VISUALS ONLY. `CollisionFidelity = Box` is the cheapest hull and nothing queries
				-- it, so the choice costs nothing.
				mesh.CanCollide = false
				mesh.CanQuery = false
				mesh.CollisionFidelity = Enum.CollisionFidelity.Box
				-- `RenderFidelity = Automatic` is Roblox's OWN distance level-of-detail, so baking a
				-- mesh per distance band would be a second mechanism answering the same question.
				-- The backdrop tier is the one exception: nobody walks the rim, so it is drawn at
				-- `Performance` from the first frame.
				mesh.RenderFidelity = if tree.tier == "backdrop"
					then Enum.RenderFidelity.Performance
					else Enum.RenderFidelity.Automatic
			end
		end
		if clone:IsA("BasePart") then
			(clone :: BasePart).Anchored = true
		end
		clone.Parent = model
		return false
	end

	-- THE PROXY: the visible bole IS the trunk collider, plus a crown box that neither collides nor
	-- is queryable -- the same answer the mesh gives, so a screenshot of the proxy tells the truth
	-- about how the real tree will behave.
	local crownStuds = geometry.crownStuds
	local crownSize = Vector3.new(crownStuds, crownStuds * 1.15, crownStuds)
	-- The crown's TOP is the species' height, then pulled down if that would leave it floating above
	-- its own trunk.
	local top = math.min(
		y + geometry.height - crownSize.Y / 2,
		y + geometry.boleStuds + crownSize.Y / 2 - config.CROWN_MIN_OVERLAP
	)
	local canopy =
		part("Crown", crownSize, Vector3.new(tree.x, top, tree.z), geometry.row.crownColor, Enum.Material.Grass, model)
	canopy.CanCollide = false
	canopy.CanQuery = false
	return true
end

-- WHERE A TREE MAY NOT STAND, and there is exactly ONE source for it: `Layout.treeDensity` returns 0
-- in every such place, so the placing step and this predicate cannot disagree about the wood --
-- which is what two copies of the rule always end up doing.
function Props.rejectTree(x: number, z: number, config, patches): boolean
	return Layout.treeDensity(x, z, config, patches) <= 0
end

-- The species row a name points at, or oak as the fallback -- the same substitution
-- `Scatter.variantKeyFor` makes, so the geometry and the mesh agree about which tree this is.
function Props.speciesRow(config, name: string?)
	if name and config.SPECIES[name] then
		return config.SPECIES[name]
	end
	return config.SPECIES.oak
end

-- ---------------------------------------------------------------- the wood

local function placeTreeList(
	parent: Instance,
	trees,
	seed: number,
	config,
	startIndex: number,
	prefix: string
): ({ [string]: number }, { [string]: boolean }, { [string]: boolean })
	local pads = Layout.pads(config)
	local counts: { [string]: number } = {}
	local proxied: { [string]: boolean } = {}
	local substituted: { [string]: boolean } = {}
	for index, tree in ipairs(trees) do
		local y = Height.atFlattened(tree.x, tree.z, seed, config, pads)
		local key, swapped = Scatter.variantKeyFor(tree.x, tree.z, seed, config, tree.species, tree.tier)
		if swapped then
			substituted[swapped] = true
		end
		local template = if key then (Loader.template(key)) else nil
		local row = if key then Assets.byKey(key) else nil
		-- Zero-padded and CONTINUED ACROSS SUB-BLOCKS, so the lexicographic order the digest and
		-- `trunks` sort by IS the placement order: "Tree10" sorts before "Tree2" and a diff would
		-- then name a shuffle, not a move.
		local name = string.format("%s%04d", prefix, startIndex + index)
		if Props.placeTree(parent, name, tree, y, config, template, row) and key ~= nil then
			proxied[key] = true
		end
		counts[tree.species] = (counts[tree.species] or 0) + 1
	end
	return counts, proxied, substituted
end

local function keyList(set: { [string]: boolean }): { string }
	local out = {}
	for key in pairs(set) do
		table.insert(out, key)
	end
	table.sort(out)
	return out
end

-- The wood, ONE SUB-BLOCK at a time, each tree a Model of a mesh plus its trunk collider.
function Props.trees(
	root: Instance,
	seed: number,
	config,
	block,
	patches,
	startIndex: number,
	fresh: boolean?,
	reject: ((number, number) -> boolean)?
): (number, { string }, { string }, { [string]: number }, { string })
	local parent = folder(propsFolder(root), "Trees", fresh)
	local trees = Scatter.trees(config, seed, block, patches, reject)
	local counts, proxied, substituted, findings
	local _result, reports = Props.withLoader(root, Props.treeKeys(config), function()
		counts, proxied, substituted = placeTreeList(parent, trees, seed, config, startIndex, "Tree")
		return true
	end)
	findings = Props.loadFindings(reports)
	return #trees, keyList(proxied), keyList(substituted), counts, findings
end

-- ONE PATCH: its own folder, so a change to the wood can never move the thicket, and so a failed
-- patch step names itself.
function Props.patchTrees(
	root: Instance,
	seed: number,
	config,
	patch
): (number, { string }, { string }, { [string]: number }, { string })
	local parent = folder(propsFolder(root), string.format("Patch_%s%02d", patch.kind, patch.index))
	local trees = Scatter.patchTrees(patch, config, seed)
	local counts, proxied, substituted, findings
	local _result, reports = Props.withLoader(root, Props.treeKeys(config), function()
		counts, proxied, substituted = placeTreeList(parent, trees, seed, config, 0, "Patch")
		return true
	end)
	findings = Props.loadFindings(reports)
	return #trees, keyList(proxied), keyList(substituted), counts, findings
end

-- THE TIE TREES, placed on purpose behind the shooter line rather than chosen out of the wood. Their
-- own folder, so `Markers` tags exactly these twelve.
function Props.tieTrees(root: Instance, seed: number, config): (number, { string }, { string })
	local parent = folder(propsFolder(root), "TieTrees")
	local points = Layout.tieTreePoints(config)
	local trees = {}
	for _, point in ipairs(points) do
		-- A MATURE OAK, by name, so a tie tree is the same OBJECT as a wood tree and `Body.tiePointFor`
		-- measures the same trunk. It is a separate folder and not a separate kind of thing.
		table.insert(trees, { x = point.x, z = point.z, species = "oak", age = "mature", tier = "mature" })
	end
	local proxied, findings
	local _result, reports = Props.withLoader(root, Props.treeKeys(config), function()
		local _counts, proxiedSet = placeTreeList(parent, trees, seed, config, 0, "TieTree")
		proxied = keyList(proxiedSet)
		return true
	end)
	findings = Props.loadFindings(reports)
	return #trees, proxied, findings
end

-- ---------------------------------------------------------------- the stands

-- THE EIGHT TIMBER STANDS. Research found no Drueckjagdbock model anywhere, which is rule 2's
-- written reason for drawing one from parts (design, "The stand (ours, because none exists)"). It is
-- replaced by one mesh later through the same key seam every other prop uses.
--
-- ONLY THE FLOOR COLLIDES AND ONLY THE FLOOR IS QUERYABLE, and that is the whole rule of this
-- layer. A collidable rail traps a player on a 7-stud platform, and a queryable rail eats the shot
-- he leans over it to take -- Task 66's log pile repeated at eye level. The floor is queryable
-- because a shot into one's own floorboards must stop somewhere.
function Props.stands(root: Instance, seed: number, config): (number, { string }, { string })
	local parent = folder(propsFolder(root), "Stands")
	local points = Layout.standPoints(config)
	local build = config.STAND_BUILD
	local pads = Layout.pads(config)
	local floorTop = config.STAND.floorStuds
	local count = 0
	local proxied = false
	local findings

	local _result, reports = Props.withLoader(root, { build.assetKey }, function()
		local template = Loader.template(build.assetKey)
		for index, point in ipairs(points) do
			local ground = Height.atFlattened(point.x, point.z, seed, config, pads)
			local stand = Instance.new("Model")
			stand.Name = string.format("Stand%d", index)
			stand.Parent = parent
			if template ~= nil then
				-- A REAL STAND REPLACES ITS WHOLE PROXY, not one part of it.
				local source = template:GetChildren()[1] or template
				local clone = source:Clone()
				clone.Name = "Mesh"
				for _, descendant in ipairs(clone:GetDescendants()) do
					if descendant:IsA("BasePart") then
						descendant.Anchored = true
					end
				end
				if clone:IsA("Model") then
					local box, size = clone:GetBoundingBox()
					clone:PivotTo(
						clone:GetPivot()
							+ Vector3.new(
								point.x - box.Position.X,
								(ground + size.Y / 2) - box.Position.Y,
								point.z - box.Position.Z
							)
					)
				end
				clone.Parent = stand
				sceneryOnly(clone)
				count += 1
				continue
			end
			proxied = true
			-- FOUR LEGS.
			local half = build.legSpan / 2
			for legIndex, corner in ipairs({
				{ dx = -half, dz = -half },
				{ dx = half, dz = -half },
				{ dx = -half, dz = half },
				{ dx = half, dz = half },
			}) do
				local leg = part(
					string.format("Leg%d", legIndex),
					build.legSize,
					Vector3.new(point.x + corner.dx, ground + build.legSize.Y / 2, point.z + corner.dz),
					build.color,
					Enum.Material.Wood,
					stand
				)
				leg.CanCollide = false
				leg.CanQuery = false
				count += 1
			end
			-- THE FLOOR, and it is the only part of this model the game touches: its TOP face is at
			-- `Map.STAND.floorStuds`, which is the number the post marker's bottom face sits on and
			-- the number the live contract check reads.
			local floor = part(
				"Floor",
				build.floor,
				Vector3.new(point.x, ground + floorTop - build.floor.Y / 2, point.z),
				build.deckColor,
				Enum.Material.WoodPlanks,
				stand
			)
			floor.CanCollide = true
			floor.CanQuery = true
			stand.PrimaryPart = floor
			count += 1
			-- THE RAIL, ON THREE SIDES: open toward the ladder, so a player is not boxed in.
			for heightIndex, railHeight in ipairs(build.railHeights) do
				for _, side in ipairs({
					{ name = "Front", dx = 0, dz = build.floor.Z / 2, size = build.rail },
					{
						name = "Left",
						dx = -build.floor.X / 2,
						dz = 0,
						size = Vector3.new(build.rail.Z, build.rail.Y, build.rail.X),
					},
					{
						name = "Right",
						dx = build.floor.X / 2,
						dz = 0,
						size = Vector3.new(build.rail.Z, build.rail.Y, build.rail.X),
					},
				}) do
					local rail = part(
						string.format("Rail%s%d", side.name, heightIndex),
						side.size,
						Vector3.new(point.x + side.dx, ground + floorTop + railHeight, point.z + side.dz),
						build.color,
						Enum.Material.Wood,
						stand
					)
					rail.CanCollide = false
					rail.CanQuery = false
					count += 1
				end
			end
			-- THE LADDER, on the back (away from the drive), so a shooter climbs from the wood side.
			for rung = 1, build.ladderRungs do
				local ladder = part(
					string.format("Rung%d", rung),
					build.ladderRung,
					Vector3.new(
						point.x,
						ground + (rung / (build.ladderRungs + 1)) * floorTop,
						point.z - build.floor.Z / 2 - build.ladderRung.Z
					),
					build.color,
					Enum.Material.Wood,
					stand
				)
				ladder.CanCollide = false
				ladder.CanQuery = false
				count += 1
			end
			-- THE ROOF, high enough that a 5-stud character stands under it.
			local roof = part(
				"Roof",
				build.roof,
				Vector3.new(point.x, ground + floorTop + build.roofClearStuds, point.z),
				build.color,
				Enum.Material.WoodPlanks,
				stand
			)
			roof.CanCollide = false
			roof.CanQuery = false
			count += 1
		end
		return true
	end)
	findings = Props.loadFindings(reports)
	return count, (if proxied then { build.assetKey } else {}), findings
end

-- ---------------------------------------------------------------- the forest floor

-- DEADWOOD: fallen trunks, stumps and broken branches. NOTHING COLLIDES AND NOTHING IS QUERYABLE --
-- a fallen trunk 1.6 studs high is a WALL to an agent that cannot jump (`AgentCanJump = false`), and
-- a log that eats a slug is an invisible wall a shooter cannot see the reason for. A walk-through log
-- is a small visible lie and it is the right one for v1; it is Karen's to overturn, and overturning
-- it costs a proved gap and a reachability run.
function Props.deadwood(root: Instance, seed: number, config, patches): number
	local parent = folder(propsFolder(root), "Deadwood")
	local pads = Layout.pads(config)
	local spec = config.DEADWOOD
	local count = 0
	local index = 0
	for _, block in ipairs(Layout.treeBlocks(config)) do
		for _, point in ipairs(Scatter.deadwood(config, seed, block, patches)) do
			index += 1
			local ground = Height.atFlattened(point.x, point.z, seed, config, pads)
			local model = Instance.new("Model")
			model.Name = string.format("Deadwood%03d", index)
			model.Parent = parent
			-- A yaw of its own, so the logs do not all lie the same way.
			local yaw = Scatter.pointKey(point.x, point.z, seed, Scatter.STREAM.rotation) * math.pi * 2
			local log = part(
				"Log",
				spec.log,
				Vector3.new(point.x, ground + spec.log.Y / 2 - spec.sink, point.z),
				spec.color,
				Enum.Material.Wood,
				model
			)
			log.CFrame = CFrame.new(log.Position) * CFrame.Angles(0, yaw, 0)
			part(
				"Stump",
				spec.stump,
				Vector3.new(
					point.x + math.cos(yaw) * spec.log.X / 2,
					ground + spec.stump.Y / 2 - spec.sink,
					point.z + math.sin(yaw) * spec.log.X / 2
				),
				spec.cutColor,
				Enum.Material.Wood,
				model
			)
			local branch = part(
				"Branch",
				spec.branch,
				Vector3.new(
					point.x + math.sin(yaw) * 4,
					ground + spec.branch.Y / 2 - spec.sink,
					point.z - math.cos(yaw) * 4
				),
				spec.color,
				Enum.Material.Wood,
				model
			)
			branch.CFrame = CFrame.new(branch.Position) * CFrame.Angles(0, yaw + 1.1, 0)
			model.PrimaryPart = log
			sceneryOnly(model)
			count += 3
		end
	end
	return count
end

-- FERNS: the ground layer that makes a forest floor read as a forest floor rather than as litter
-- with trees on it. Cover for the eye only.
function Props.ferns(root: Instance, seed: number, config, block, patches, startIndex: number, fresh: boolean?): number
	local parent = folder(propsFolder(root), "Ferns", fresh)
	local pads = Layout.pads(config)
	local spec = config.FERNS
	local points = Scatter.ferns(config, seed, block, patches)
	for index, point in ipairs(points) do
		local ground = Height.atFlattened(point.x, point.z, seed, config, pads)
		local wet = Height.wetAt(point.x, point.z, seed, config) > 0.5
		local fern = part(
			string.format("Fern%04d", startIndex + index),
			spec.size,
			Vector3.new(point.x, ground + spec.size.Y / 2 - spec.sink, point.z),
			if wet then spec.wetColor else spec.color,
			Enum.Material.LeafyGrass,
			parent
		)
		fern.CanCollide = false
		fern.CanQuery = false
		fern.CastShadow = false
	end
	return #points
end

-- BRUSH: low cover that hides a boar and blocks nothing.
function Props.brush(root: Instance, seed: number, config, block, patches, startIndex: number, fresh: boolean?): number
	local parent = folder(propsFolder(root), "Brush", fresh)
	local pads = Layout.pads(config)
	local spec = config.BRUSH
	local points = Scatter.brush(config, seed, block, patches)
	for index, point in ipairs(points) do
		local ground = Height.atFlattened(point.x, point.z, seed, config, pads)
		local bush = part(
			string.format("Brush%04d", startIndex + index),
			spec.size,
			Vector3.new(point.x, ground + spec.size.Y / 2 - spec.sink, point.z),
			spec.color,
			Enum.Material.LeafyGrass,
			parent
		)
		-- NEITHER COLLIDABLE NOR QUERYABLE: a bush that stops a slug is an invisible wall a shooter
		-- cannot see the reason for, and a bush that stops a driver is worse. Cover for the eye.
		bush.CanCollide = false
		bush.CanQuery = false
	end
	return #points
end

-- ---------------------------------------------------------------- the hedgerows (retired layer)

-- ONE HEDGEROW LINE per call. The layer is switched off (`Config.INCLUDE.hedges`), and this function
-- stays with it for the reason Layout's retired-layer note gives: FLIPPING ONE ROW BACK ON HAS TO
-- BRING THE LAYER BACK, and a step that reports a line it does not build is worse than no step.
--
-- `gates` comes from Scatter and the segments from Layout, so this decides nothing about where a
-- hedge goes -- it only builds what it is handed.
function Props.hedge(root: Instance, seed: number, config, lineIndex: number, line, gates: { number }): number
	local parent = folder(propsFolder(root), string.format("Hedge%02d", lineIndex))
	local pads = Layout.pads(config)
	local points = Layout.hedgeSegments(line, gates, config)
	local size = config.HEDGE.size
	-- A hedge running along z is the same box turned a quarter: the segment's long axis follows the
	-- line, or a z-line would be a row of 24-stud gaps with 3-stud posts in them.
	local laid = if line.axis == "x" then size else Vector3.new(size.Z, size.Y, size.X)
	for index, point in ipairs(points) do
		local y = Height.atFlattened(point.x, point.z, seed, config, pads)
		part(
			string.format("Hedge%02d_%03d", lineIndex, index),
			laid,
			Vector3.new(point.x, y + size.Y / 2, point.z),
			config.PROXY_COLOR.hedge,
			Enum.Material.Grass,
			parent
		)
	end
	return #points
end

-- ---------------------------------------------------------------- the stakes

-- THE STAKES BESIDE EACH STAND, built from `Layout.furniture`'s list. Like every other prop
-- function this decides NOTHING about where anything goes -- it is handed pieces and it places them.
--
-- ONE GROUND HEIGHT PER OBJECT: the piece carries `anchorX`/`anchorZ`, so a stake and its cap stand
-- on one plane instead of each following the heightfield under itself.
function Props.furniture(root: Instance, seed: number, config): number
	local parent = folder(propsFolder(root), "Furniture")
	local pads = Layout.pads(config)
	local grounds: { [string]: number } = {}
	local count = 0
	for _, piece in ipairs(Layout.furniture(config)) do
		local anchorKey = string.format("%d:%d", math.floor(piece.anchorX * 4), math.floor(piece.anchorZ * 4))
		local ground = grounds[anchorKey]
		if ground == nil then
			ground = Height.atFlattened(piece.anchorX, piece.anchorZ, seed, config, pads)
			grounds[anchorKey] = ground
		end
		local made = part(
			piece.name,
			piece.size,
			Vector3.new(piece.x, ground + piece.base + piece.size.Y / 2, piece.z),
			piece.color,
			piece.material,
			parent
		)
		sceneryOnly(made)
		count += 1
	end
	return count
end

-- ---------------------------------------------------------------- reading it back

-- The taggable part of every tree in one folder, in the order Props placed them, for Markers to tag
-- the tie trees from. It is the Model's PrimaryPart -- the TRUNK COLLIDER -- which is the part
-- `Body.tiePointFor` must measure and never the crown or the mesh.
function Props.trunks(root: Instance, folderName: string): { BasePart }
	local out: { BasePart } = {}
	local props = root:FindFirstChild("Props")
	local trees = props and props:FindFirstChild(folderName)
	if trees == nil then
		return out
	end
	local models = trees:GetChildren()
	table.sort(models, function(a, b)
		return a.Name < b.Name
	end)
	for _, model in ipairs(models) do
		local stem: BasePart? = nil
		if model:IsA("BasePart") then
			stem = model
		elseif model:IsA("Model") then
			stem = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		end
		if stem then
			table.insert(out, stem)
		end
	end
	return out
end

return Props
