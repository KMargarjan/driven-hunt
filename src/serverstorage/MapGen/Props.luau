--!strict
-- MapGen.Props: THE ONLY WRITER OF `Workspace.DrivenHuntMap.Props` (design section 2.2). It writes
-- no Terrain and places no marker, and it is the only module that inserts an asset.
--
-- EVERY STEP IS IDEMPOTENT: each call destroys its own folder and rebuilds it, so re-running a failed
-- step does not leave a second wood behind (design section 5.4).
--
-- NO TEMPLATE IS EVER CACHED OUTSIDE THE RUN. `ServerStorage` and `ReplicatedStorage` are fully
-- Rojo-owned with `$ignoreUnknownInstances: false`, so a template parked there is DELETED at Karen's
-- next Connect (CLAUDE.md, "Rojo DELETES Studio-created instances in Rojo-owned containers"). A cache
-- that empties itself between sessions is a bug generator, so the Assets folder lives under the map
-- root for the length of one run and is destroyed at the end of it (design section 8.2).
--
--   InsertService:LoadAsset https://create.roblox.com/docs/reference/engine/classes/InsertService
--
-- Design: docs/design/map-generator.md (sections 2.2, 8.2, 8.3, 8.4)
local InsertService = game:GetService("InsertService")

local Assets = require(script.Parent:WaitForChild("Assets"))
local Height = require(script.Parent:WaitForChild("Height"))
local Layout = require(script.Parent:WaitForChild("Layout"))
local Scatter = require(script.Parent:WaitForChild("Scatter"))

local Props = {}

Props.ASSETS_FOLDER = "Assets"

-- The attribute every placed tree carries, naming the `Config.SPECIES` row it was built from (or
-- `Config.TREE_PROXY.name` for a tie tree). One constant, read by the spec, so a rename cannot make a
-- spec pass by looking for an attribute nothing writes.
Props.SPECIES_ATTRIBUTE = "Species"

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
-- makes re-running a step idempotent. THE WOOD IS THE EXCEPTION (M2.8b): it is built in four
-- quadrant steps, so the first clears and the other three append -- and the first build of this
-- shape ended with only the last quadrant in the world, because every step wiped the one before it.
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

-- THE FURNITURE LAYER'S ONE RULE, IN ONE PLACE (Task 66 review note 1, audit-005): a slug passes
-- through anything a player walks through. Nothing in the furniture layer collides -- the contract
-- forbids a collidable part near the road and half the layer stands there on purpose (Config.FURNITURE
-- says why) -- so nothing in it may be QUERYABLE either, or the grey-box log pile 20 studs downrange of
-- shooter post 7 absorbs a slug a player can walk through. Before this, `part()` left `CanQuery` at its
-- default `true` and only `CanCollide` was decided, which is the "two correct pieces of code
-- disagreeing" shape: one of them stopped the player and the other stopped the bullet.
--
-- IT IS NOT A PROJECT-WIDE RULE and must not become one: a tree CROWN is `CanCollide = false` and
-- `CanQuery = true` ON PURPOSE (Props.placeTree, Task 63) -- a shot into the canopy stops in the canopy
-- while the navmesh sees trunks only. This is the FURNITURE's rule, applied to the whole layer at once
-- rather than remembered per piece, and it is the only writer of either property in `Props.furniture`.
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

-- A FREE MODEL WITH A SCRIPT IN IT IS REFUSED, NOT STRIPPED (design section 8.4). One surviving
-- Script under Workspace makes harness check 5 fail every run from then on, and a stripped model is
-- half-functional in ways nobody looks for: the right answer is a different asset.
function Props.scriptIn(template: Instance): string?
	for _, descendant in ipairs(template:GetDescendants()) do
		if descendant:IsA("LuaSourceContainer") then
			return descendant:GetFullName()
		end
	end
	return nil
end

-- The template for a key, inserted once per run into the run's own Assets folder, or nil when there
-- is no id yet -- which means "the caller places a proxy", not "the step failed" (section 8.3).
--
-- EVERY PLACING STEP CALLS THIS FIRST, and proxies only on nil. That is the whole of section 8.3: the
-- day a row lands in `Assets.ROWS`, the same step clones the asset instead of building a box, with no
-- other change. `proxyUsed` therefore reports the keys that WERE proxied, not the keys that exist.
-- In M2.1 `Assets.ROWS` is empty, so the nil branch is the one that runs and the insertion branch
-- below -- LoadAsset, the cache, the script refusal -- is dormant until the first id (row 43a(d)).
function Props.template(key: string, root: Instance): (Instance?, string?)
	local row = Assets.byKey(key)
	if row == nil then
		return nil, nil
	end
	local cache = root:FindFirstChild(Props.ASSETS_FOLDER)
	if cache == nil then
		local made = Instance.new("Folder")
		made.Name = Props.ASSETS_FOLDER
		made.Parent = root
		cache = made
	end
	local existing = cache:FindFirstChild(key)
	if existing then
		return existing, nil
	end
	local ok, result = pcall(function()
		return InsertService:LoadAsset(row.id)
	end)
	if not ok then
		return nil, string.format("LoadAsset(%d) for %s failed: %s", row.id, key, tostring(result))
	end
	local container = result :: Instance
	local found = Props.scriptIn(container)
	if found then
		container:Destroy()
		return nil, string.format("asset %d for %s contains a script (%s); refused, not stripped", row.id, key, found)
	end
	container.Name = key
	container.Parent = cache
	return container, nil
end

function Props.clearAssets(root: Instance)
	local cache = root:FindFirstChild(Props.ASSETS_FOLDER)
	if cache then
		cache:Destroy()
	end
end

-- One placed thing: a clone of the asset when there is one, and a proxy Part of the same footprint
-- when there is not. Returns the instance and whether it was a proxy, so the caller can count.
local function placed(
	template: Instance?,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): (Instance, boolean)
	if template then
		-- InsertService:LoadAsset returns a container Model; the asset itself is its first child.
		local source = template:GetChildren()[1] or template
		local clone = source:Clone()
		clone.Name = name
		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
		end
		if clone:IsA("Model") then
			clone:PivotTo(CFrame.new(position))
		elseif clone:IsA("BasePart") then
			clone.Anchored = true
			clone.Position = position
		end
		clone.Parent = parent
		return clone, false
	end
	return part(name, size, position, color, material, parent), true
end

-- ONE HEDGEROW LINE per call, so a failed line names itself and re-running it rebuilds only that
-- line. `gates` comes from Scatter and the segments from Layout, so this function decides nothing
-- about where a hedge goes -- it only builds what it is handed.
function Props.hedge(
	root: Instance,
	seed: number,
	config,
	lineIndex: number,
	line,
	gates: { number }
): (number, { string }, string?)
	local template, why = Props.template(Assets.KEY.hedge, root)
	if why then
		return 0, {}, why
	end
	local parent = folder(propsFolder(root), string.format("Hedge%02d", lineIndex))
	local pads = Layout.pads(config)
	local points = Layout.hedgeSegments(line, gates, config)
	local size = config.HEDGE.size
	-- A hedge running along z is the same box turned a quarter: the segment's long axis follows the
	-- line, or a z-line would be a row of 24-stud gaps with 3-stud posts in them.
	local laid = if line.axis == "x" then size else Vector3.new(size.Z, size.Y, size.X)
	local proxied = 0
	for index, point in ipairs(points) do
		local y = Height.atFlattened(point.x, point.z, seed, config, pads, Layout.bogDepth)
		local _, wasProxy = placed(
			template,
			string.format("Hedge%02d_%03d", lineIndex, index),
			laid,
			Vector3.new(point.x, y + size.Y / 2, point.z),
			config.PROXY_COLOR.hedge,
			Enum.Material.Grass,
			parent
		)
		if wasProxy then
			proxied += 1
		end
	end
	return #points, (if proxied > 0 then { Assets.KEY.hedge } else {}), nil
end

-- THE ROAD'S FURNITURE (M2.8c), built from `Layout.furniture`'s list. Like `Props.hedge`, this
-- function decides NOTHING about where anything goes -- it is handed pieces and it places them.
--
-- NOTHING IT PLACES COLLIDES, without exception. `MapGen.verifyContract` fails the build for any
-- collidable part within `Map.ROAD.halfWidth + verge` of the road's centreline, over the road's
-- whole length (Task 58 round 1 finding 1, after a hedge wall stood across the gravel and
-- reachability pathed politely around it). Half this layer stands inside that envelope on purpose --
-- stakes beside the stand, log piles on the verge, a barrier across each end -- so the rule is
-- applied to the whole layer rather than remembered piece by piece. It also means the furniture
-- cannot change a single pathfinding answer: `reach` before and after must be identical.
--
-- ONE GROUND HEIGHT PER OBJECT: the piece carries `anchorX`/`anchorZ`, so a high seat's four legs
-- and its deck stand on one plane instead of each following the heightfield under itself.
function Props.furniture(root: Instance, seed: number, config): (number, { string }, string?)
	local template, why = Props.template(Assets.KEY.highSeat, root)
	if why then
		return 0, {}, why
	end
	local parent = folder(propsFolder(root), "Furniture")
	local pads = Layout.pads(config)
	local pieces = Layout.furniture(config)
	local grounds: { [string]: number } = {}
	local proxied = false
	local placedSeats: { [number]: boolean } = {}
	local count = 0
	for _, piece in ipairs(pieces) do
		local anchorKey = string.format("%d:%d", math.floor(piece.anchorX * 4), math.floor(piece.anchorZ * 4))
		local ground = grounds[anchorKey]
		if ground == nil then
			ground = Height.atFlattened(piece.anchorX, piece.anchorZ, seed, config, pads, Layout.bogDepth)
			grounds[anchorKey] = ground
		end
		-- A REAL HIGH SEAT REPLACES ITS WHOLE PROXY, not one part of it: when `prop.highseat` has an
		-- id, the model goes in at the seat's centre and its seven boxes are not built at all.
		if template and string.sub(piece.kind, 1, 8) == "highSeat" then
			local seatIndex = tonumber(string.match(piece.name, "^HighSeat(%d+)") or "") or 0
			if not placedSeats[seatIndex] then
				placedSeats[seatIndex] = true
				local model = placed(
					template,
					string.format("HighSeat%d", seatIndex),
					piece.size,
					Vector3.new(piece.anchorX, ground, piece.anchorZ),
					piece.color,
					piece.material,
					parent
				)
				sceneryOnly(model :: Instance)
				count += 1
			end
			continue
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
		if string.sub(piece.kind, 1, 8) == "highSeat" then
			proxied = true
		end
	end
	return count, (if proxied then { Assets.KEY.highSeat } else {}), nil
end

-- ONE TREE, and the only place in the repo that knows what a tree is made of. Returns true when it
-- placed a PROXY, so a caller can report `proxyUsed` for what was actually proxied. The wood and the
-- tie trees both come through here: two builders would drift, and a tie tree that is not the same
-- object as a wood tree is a bug waiting for M2.3.
function Props.speciesRow(config, name: string?)
	if name then
		for _, row in ipairs(config.SPECIES) do
			if row.name == name then
				return row
			end
		end
	end
	return config.TREE_PROXY -- the tie trees, which are placed on purpose and are not of the wood
end

function Props.placeTree(
	template: Instance?,
	parent: Instance,
	name: string,
	point,
	y: number,
	config,
	species: string?
): boolean
	local row = Props.speciesRow(config, species)
	local trunk, crown = row.trunk, row.crown
	if template then
		local clone = placed(
			template,
			name,
			trunk,
			Vector3.new(point.x, y, point.z),
			config.PROXY_COLOR.tree,
			Enum.Material.Wood,
			parent
		)
		clone:SetAttribute(Props.SPECIES_ATTRIBUTE, row.name)
		return false
	end
	-- The proxy: trunk plus crown, one Model, so a tie can hold on to the trunk and a screenshot
	-- answers "woods or poles" honestly.
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	-- WHAT WAS PLANTED, ON THE THING THAT WAS PLANTED (audit-005 must-fix 2). Until this attribute
	-- existed, every species claim in the repo was a claim about `Scatter.speciesAt` -- a pure
	-- function -- and nothing compared it against the wood in the world; a monoculture built from one
	-- template passed all of them. `tests/server/map_contract.spec.luau` reads it back off the BUILT
	-- trees and compares it against the sampler tree by tree. Digest.of hashes name, className,
	-- Position, Size and tags, so an attribute cannot change a map's digest.
	model:SetAttribute(Props.SPECIES_ATTRIBUTE, row.name)
	local stem =
		part("Trunk", trunk, Vector3.new(point.x, y + trunk.Y / 2, point.z), row.trunkColor, Enum.Material.Wood, model)
	-- THE CROWN'S TOP IS THE SPECIES' HEIGHT, which is the number docs/design/asset-pipeline.md
	-- section 12.1 will build the mesh to -- so the grey box teaches the truth about how tall this
	-- tree is. It is then pulled down if that would leave it floating above its own trunk.
	local top = math.min(y + row.height - crown.Y / 2, y + trunk.Y + crown.Y / 2 - config.CROWN_MIN_OVERLAP)
	local canopy = part("Crown", crown, Vector3.new(point.x, top, point.z), row.crownColor, Enum.Material.Grass, model)
	-- THE CANOPY DOES NOT BLOCK THE GROUND GAME (design section 7.1): the navmesh and the boar see
	-- trunks only, so a wooded drive is still walkable -- while a shot into the canopy still stops in
	-- the canopy, because CanQuery stays true.
	canopy.CanCollide = false
	model.PrimaryPart = stem
	return true
end

-- WHERE A TREE MAY NOT STAND, and since M2.8b there is exactly ONE source for it:
-- `Layout.treeDensity` returns 0 in every such place -- a field, a bench and its verge, a track, the
-- bog, a hedge line's clearance, a spawn pad -- so the placing step and this predicate cannot
-- disagree about the wood, which is what two copies of the rule always end up doing.
--
-- THE CORRIDOR IS NO LONGER A REASON. Until M2.8b nothing could stand in the drive at all, which is
-- what made the drive a bare lane through a decorated backdrop; the wood is the drive now, and what
-- keeps it walkable is the sampler's guaranteed 11-stud separation against the boar's 4-stud need
-- (design section 7.3), measured by the walkability spec and by `MapGen.reachability`.
function Props.rejectTree(x: number, z: number, config): boolean
	return Layout.treeDensity(x, z, config) <= 0
end

-- The wood, ONE BLOCK at a time: each tree a Model of trunk plus crown so the screenshots answer
-- "does this read as woods or as poles" (design section 13.3). Each is a PROXY while there is no
-- asset id, and a proxy is the same footprint and height as the model that replaces it.
function Props.trees(
	root: Instance,
	seed: number,
	config,
	block,
	startIndex: number,
	fresh: boolean?
): (number, { string }, string?, { [string]: number })
	local counts: { [string]: number } = {}
	-- ONE TEMPLATE PER SPECIES, ASKED FOR BY THE SPECIES' OWN KEY (audit-005 must-fix 2). This used to
	-- be a single `Assets.KEY.treeSpruce` fetched once for the whole block and handed to every tree,
	-- whatever `Scatter.speciesAt` returned -- so the first tree id would have turned the entire wood
	-- into one mesh with every species spec still green. `Props.template` caches per key inside the
	-- run's own Assets folder, so this is one lookup per species per step and not one per tree.
	local templates: { [string]: Instance } = {}
	for _, row in ipairs(config.SPECIES) do
		local template, why = Props.template(row.assetKey, root)
		if why then
			return 0, {}, why, counts
		end
		if template then
			templates[row.name] = template
		end
	end
	local parent = folder(propsFolder(root), "Trees", fresh)
	local pads = Layout.pads(config)
	local points = Scatter.trees(config, seed, block, function(x, z)
		return Props.rejectTree(x, z, config)
	end)
	local proxied = 0
	local keys: { [string]: boolean } = {}
	for index, point in ipairs(points) do
		local y = Height.atFlattened(point.x, point.z, seed, config, pads, Layout.bogDepth)
		local species = Scatter.speciesAt(point.x, point.z, seed, config, y)
		counts[species] = (counts[species] or 0) + 1
		-- Zero-padded and CONTINUED ACROSS BLOCKS, so the lexicographic order the digest and `trunks`
		-- sort by IS the placement order: "Tree10" sorts before "Tree2" and a diff would then name a
		-- shuffle, not a move.
		local name = string.format("Tree%04d", startIndex + index)
		if Props.placeTree(templates[species], parent, name, point, y, config, species) then
			proxied += 1
			-- THE KEY THIS SPECIES ASKED FOR, so the step's `proxyUsed` names four keys in a mixed
			-- wood and one key in a monoculture -- which is the difference the spec asserts.
			keys[Props.speciesRow(config, species).assetKey] = true
		end
	end
	local used: { string } = {}
	for key in pairs(keys) do
		table.insert(used, key)
	end
	return #points, used, nil, counts
end

-- BRUSH: low cover that hides a boar and blocks nothing (design section 7.4). One quadrant per step,
-- the same four blocks the wood uses, so a slow step names a quarter of the map rather than "props".
function Props.brush(
	root: Instance,
	seed: number,
	config,
	block,
	startIndex: number,
	fresh: boolean?
): (number, string?)
	local parent = folder(propsFolder(root), "Brush", fresh)
	local pads = Layout.pads(config)
	local points = Scatter.brush(config, seed, block, function(x, z)
		-- Brush lives in the WOOD: everywhere a tree could stand, plus nowhere a tree could not.
		return Props.rejectTree(x, z, config)
	end)
	local brush = config.BRUSH
	for index, point in ipairs(points) do
		local y = Height.atFlattened(point.x, point.z, seed, config, pads, Layout.bogDepth)
		local bush = part(
			string.format("Brush%04d", startIndex + index),
			brush.size,
			Vector3.new(point.x, y + brush.size.Y / 2 - brush.sink, point.z),
			brush.color,
			Enum.Material.LeafyGrass,
			parent
		)
		-- NEITHER COLLIDABLE NOR QUERYABLE: a bush that stops a slug is an invisible wall a shooter
		-- cannot see the reason for, and a bush that stops a driver is worse. Cover for the eye.
		bush.CanCollide = false
		bush.CanQuery = false
	end
	return #points, nil
end

-- The taggable part of every tree in one folder, in the order Props placed them, for Markers to tag
-- the tie trees from. A proxy's is its Trunk (which is also its PrimaryPart); an asset's is whatever
-- the model calls its PrimaryPart, falling back to its first BasePart -- so this works before and
-- after the ids arrive, which is the point of section 8.3.
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

-- THE TIE TREES, placed on purpose behind the shooter line rather than chosen out of the wood
-- (Layout.tieTreePoints says why). Their own folder, so `Markers` tags exactly these twelve and a
-- change to the wood can never move which tree a punished shooter is tied to.
function Props.tieTrees(root: Instance, seed: number, config): (number, { string }, string?)
	-- THE TIE TREES' OWN ROW NAMES THEIR KEY too (`Config.TREE_PROXY.assetKey`), so no call site in
	-- this file spells an asset key out by hand any more: the row a tree is built from decides both
	-- what it looks like and which asset replaces it.
	local row = Props.speciesRow(config, nil)
	local template, why = Props.template(row.assetKey, root)
	if why then
		return 0, {}, why
	end
	local parent = folder(propsFolder(root), "TieTrees")
	local pads = Layout.pads(config)
	local points = Layout.tieTreePoints(config)
	local proxied = 0
	for index, point in ipairs(points) do
		local y = Height.atFlattened(point.x, point.z, seed, config, pads, Layout.bogDepth)
		local wasProxy = Props.placeTree(template, parent, string.format("TieTree%03d", index), point, y, config)
		if wasProxy then
			proxied += 1
		end
	end
	return #points, (if proxied > 0 then { row.assetKey } else {}), nil
end

return Props
