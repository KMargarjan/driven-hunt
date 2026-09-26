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
-- UNEXERCISED IN M2.1: `Assets.ROWS` is empty, so this returns nil for every key and the insertion
-- path below has never run. It is written now because the refusal above is the part that must exist
-- before the first id arrives, not after it.
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

-- The hedgerow: one segment per polyline point, each sitting on the ground under it.
function Props.hedge(root: Instance, seed: number, config): (number, { string })
	local parent = folder(propsFolder(root), "Hedge")
	local pads = Layout.pads(config)
	local points = Layout.hedgerow(config)
	local size = config.HEDGE.size
	for index, point in ipairs(points) do
		local y = Height.atFlattened(point.x, point.z, seed, config, pads)
		part(
			string.format("Hedge%03d", index),
			size,
			Vector3.new(point.x, y + size.Y / 2, point.z),
			config.PROXY_COLOR.hedge,
			Enum.Material.Grass,
			parent
		)
	end
	return #points, { Assets.KEY.hedge }
end

-- The wood: `SLICE.treeCount` trees, each a Model of trunk plus crown so the screenshots answer
-- "does this read as woods or as poles" (design section 13.3). Each is a PROXY while there is no
-- asset id, and a proxy is the same footprint and height as the model that replaces it.
function Props.trees(root: Instance, seed: number, config): (number, { string })
	local parent = folder(propsFolder(root), "Trees")
	local pads = Layout.pads(config)
	local points = Scatter.trees(config, seed, function(x, z)
		return Layout.inCorridor(x, z, config) or Layout.onTrack(x, z, config)
	end)
	local trunk, crown = config.TREE_PROXY.trunk, config.TREE_PROXY.crown
	for index, point in ipairs(points) do
		local y = Height.atFlattened(point.x, point.z, seed, config, pads)
		local model = Instance.new("Model")
		-- Zero-padded, so the lexicographic order the digest and `trunks` sort by IS the placement
		-- order: "Tree10" sorts before "Tree2" and a diff would then name a shuffle, not a move.
		model.Name = string.format("Tree%03d", index)
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
	end
	return #points, { Assets.KEY.treeSpruce }
end

-- Every trunk, in the order Props placed them, for Markers to tag the tie trees from.
function Props.trunks(root: Instance): { BasePart }
	local out: { BasePart } = {}
	local props = root:FindFirstChild("Props")
	local trees = props and props:FindFirstChild("Trees")
	if trees == nil then
		return out
	end
	local models = trees:GetChildren()
	table.sort(models, function(a, b)
		return a.Name < b.Name
	end)
	for _, model in ipairs(models) do
		local stem = model:FindFirstChild("Trunk")
		if stem and stem:IsA("BasePart") then
			table.insert(out, stem)
		end
	end
	return out
end

return Props
