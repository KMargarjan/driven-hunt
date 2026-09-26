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

local function folder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing then
		existing:Destroy() -- idempotence: the folder is rebuilt, never added to
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

-- ONE TREE, and the only place in the repo that knows what a tree is made of. Returns true when it
-- placed a PROXY, so a caller can report `proxyUsed` for what was actually proxied. The wood and the
-- tie trees both come through here: two builders would drift, and a tie tree that is not the same
-- object as a wood tree is a bug waiting for M2.3.
function Props.placeTree(template: Instance?, parent: Instance, name: string, point, y: number, config): boolean
	local trunk, crown = config.TREE_PROXY.trunk, config.TREE_PROXY.crown
	if template then
		placed(
			template,
			name,
			trunk,
			Vector3.new(point.x, y, point.z),
			config.PROXY_COLOR.tree,
			Enum.Material.Wood,
			parent
		)
		return false
	end
	-- The proxy: trunk plus crown, one Model, so a tie can hold on to the trunk and a screenshot
	-- answers "woods or poles" honestly.
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	local stem = part(
		"Trunk",
		trunk,
		Vector3.new(point.x, y + trunk.Y / 2, point.z),
		Color3.fromRGB(78, 62, 46),
		Enum.Material.Wood,
		model
	)
	part(
		"Crown",
		crown,
		Vector3.new(point.x, y + trunk.Y + crown.Y / 2 - 3, point.z),
		config.PROXY_COLOR.tree,
		Enum.Material.Grass,
		model
	)
	model.PrimaryPart = stem
	return true
end

-- WHERE A TREE MAY NOT STAND. The corridor is the drive; a track is a track; the bog is wet; and a
-- trunk inside a hedgerow is the cosmetic fault review round 3 of Task 43 found on the slice's flank
-- (row 43a(o)). One predicate, used by the placing step AND by the spec, so they cannot disagree.
function Props.rejectTree(x: number, z: number, config): boolean
	return Layout.inCorridor(x, z, config)
		or Layout.onTrack(x, z, config)
		or Layout.bogDepth(x, z, config) > 0
		or Layout.distanceToHedge(x, z, config) < config.SCATTER_CLEARANCE
end

-- The wood: `WORLD.treeCount` trees, each a Model of trunk plus crown so the screenshots answer
-- "does this read as woods or as poles" (design section 13.3). Each is a PROXY while there is no
-- asset id, and a proxy is the same footprint and height as the model that replaces it.
function Props.trees(root: Instance, seed: number, config): (number, { string }, string?)
	local template, why = Props.template(Assets.KEY.treeSpruce, root)
	if why then
		return 0, {}, why
	end
	local parent = folder(propsFolder(root), "Trees")
	local pads = Layout.pads(config)
	local points = Scatter.trees(config, seed, function(x, z)
		return Props.rejectTree(x, z, config)
	end)
	local proxied = 0
	for index, point in ipairs(points) do
		local y = Height.atFlattened(point.x, point.z, seed, config, pads, Layout.bogDepth)
		-- Zero-padded, so the lexicographic order the digest and `trunks` sort by IS the placement
		-- order: "Tree10" sorts before "Tree2" and a diff would then name a shuffle, not a move.
		if Props.placeTree(template, parent, string.format("Tree%03d", index), point, y, config) then
			proxied += 1
		end
	end
	return #points, (if proxied > 0 then { Assets.KEY.treeSpruce } else {}), nil
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
	local template, why = Props.template(Assets.KEY.treeSpruce, root)
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
	return #points, (if proxied > 0 then { Assets.KEY.treeSpruce } else {}), nil
end

return Props
