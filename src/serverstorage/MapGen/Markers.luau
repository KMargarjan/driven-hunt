--!strict
-- MapGen.Markers: THE ONLY WRITER OF `Workspace.DrivenHuntMap.Markers` AND THE ONLY CALLER OF
-- `CollectionService:AddTag` IN THE GENERATED MAP (design section 2.2). It writes no Terrain and
-- places no prop; it tags the trunks `Props` already made, and it never moves or creates one.
--
-- Tags, not names and not attributes, and NEVER BOTH: `Match.Markers` finds the world by tag, and two
-- representations of one fact is this project's named failure mode (design section 13.5 measurement
-- B, which is what decides whether that stays true across a save and reopen).
--
--   CollectionService https://create.roblox.com/docs/reference/engine/classes/CollectionService
--   CFrame.lookAt     https://create.roblox.com/docs/reference/engine/datatypes/CFrame#lookAt
--
-- THE DRIVE LINE'S FACING IS LOAD-BEARING. `src/server/Weapon/SafetyArc.luau` reads the line part's
-- LookVector as "toward the drivers", and `tests/server/map_contract.spec.luau` asserts
-- LookVector:Dot(Vector3.zAxis) > 0.99. A line built facing the other way makes the safety rule fire
-- on exactly the wrong shots, which is why the CFrame here is built with an explicit lookAt and not
-- from a rotation number.
--
-- Design: docs/design/map-generator.md (sections 2.2, 4.2, 4.3, 13.1)
local CollectionService = game:GetService("CollectionService")

local Map = require(script.Parent:WaitForChild("Contract"))

local Height = require(script.Parent:WaitForChild("Height"))
local Layout = require(script.Parent:WaitForChild("Layout"))
local Props = require(script.Parent:WaitForChild("Props"))

local Markers = {}

-- A marker a player stands at collides; a line, a start box and a spawn pad are reference geometry
-- and must not be something to trip over.
local SOLID = { shooterPost = true }

local function markersFolder(root: Instance): Folder
	local existing = root:FindFirstChild("Markers")
	if existing then
		existing:Destroy() -- idempotence: the whole folder is rebuilt, tags and all
	end
	local made = Instance.new("Folder")
	made.Name = "Markers"
	made.Parent = root
	return made
end

-- Places the 14 marker parts and tags them. Returns how many of each kind were tagged.
function Markers.place(root: Instance, seed: number, config): { [string]: number }
	local parent = markersFolder(root)
	local pads = Layout.pads(config)
	local counts: { [string]: number } = {}
	for _, marker in ipairs(Layout.markers(config)) do
		local ground = Height.atFlattened(marker.x, marker.z, seed, config, pads)
		local y = ground + marker.size.Y / 2
		local position = Vector3.new(marker.x, y, marker.z)
		local part = Instance.new("Part")
		part.Name = marker.name
		part.Size = marker.size
		-- +Z is the drivers' side of the line, so this LookVector points at them.
		part.CFrame = CFrame.lookAt(position, position + Vector3.zAxis)
		part.Anchored = true
		part.CanCollide = SOLID[marker.kind] == true
		part.Color = config.PROXY_COLOR.marker
		part.Material = Enum.Material.SmoothPlastic
		part.Transparency = if SOLID[marker.kind] then 0 else 0.5
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = parent
		CollectionService:AddTag(part, Map.TAGS[marker.kind])
		counts[marker.kind] = (counts[marker.kind] or 0) + 1
	end
	return counts
end

-- The tie trees: the `SLICE.tieTrees` trunks nearest the shooter line, tagged where they stand. A
-- player tied to a spruce 900 studs away is a teleport, not a penalty (design section 4.3).
function Markers.tagTieTrees(root: Instance, config): number
	local trunks = Props.trunks(root)
	local points = {}
	for _, trunk in ipairs(trunks) do
		table.insert(points, { x = trunk.Position.X, z = trunk.Position.Z })
	end
	local tagged = 0
	for _, index in ipairs(Layout.tieTrees(points, config)) do
		local trunk = trunks[index]
		if trunk and not CollectionService:HasTag(trunk, Map.TAGS.tree) then
			CollectionService:AddTag(trunk, Map.TAGS.tree)
			tagged += 1
		end
	end
	return tagged
end

-- Every tagged instance under the root, with its tags, for the digest and the contract check.
function Markers.tagged(root: Instance): { { instance: Instance, tags: { string } } }
	local out = {}
	for _, tag in pairs(Map.TAGS) do
		for _, instance in ipairs(CollectionService:GetTagged(tag)) do
			if instance:IsDescendantOf(root) then
				table.insert(out, { instance = instance, tags = CollectionService:GetTags(instance) })
			end
		end
	end
	return out
end

-- How many instances carry each tag INSIDE the root. A tag on something outside it is not the map's.
function Markers.counts(root: Instance): { [string]: number }
	local counts: { [string]: number } = {}
	for kind, tag in pairs(Map.TAGS) do
		local total = 0
		for _, instance in ipairs(CollectionService:GetTagged(tag)) do
			if instance:IsDescendantOf(root) then
				total += 1
			end
		end
		counts[kind] = total
	end
	return counts
end

return Markers
