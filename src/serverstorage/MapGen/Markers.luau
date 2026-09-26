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

-- EVERY MARKER IS INVISIBLE AND INERT (design section 4.3): Anchored, CanCollide = false,
-- CanQuery = false, Transparency = 1. Round 2 of the review caught the opposite here -- eight solid
-- white posts and six translucent boxes -- and the design's own sentence is the reason it matters:
-- "a marker that can be shot, walked into or collided with is a gameplay object pretending to be
-- metadata". CanQuery is the load-bearing one: `Weapon.Cast` builds RaycastParams with an Exclude
-- filter and no RespectCanCollide, so a CanCollide = false part still stops a pellet. A 340-stud
-- DriveLine across the shooter line would have eaten shots.
--
-- The visible grey box is TestArena's job, and it still has it: this is the generated map's metadata,
-- not its geometry.

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
		local ground = Height.atFlattened(marker.x, marker.z, seed, config, pads, Layout.bogDepth)
		local y = ground + marker.size.Y / 2
		local position = Vector3.new(marker.x, y, marker.z)
		local part = Instance.new("Part")
		part.Name = marker.name
		part.Size = marker.size
		-- +Z is the drivers' side of the line, so this LookVector points at them.
		part.CFrame = CFrame.lookAt(position, position + Vector3.zAxis)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.CastShadow = false
		part.Color = config.PROXY_COLOR.marker
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = parent
		CollectionService:AddTag(part, Map.TAGS[marker.kind])
		counts[marker.kind] = (counts[marker.kind] or 0) + 1
	end
	return counts
end

-- THE TIE TREES: every trunk in the `TieTrees` folder, which `Props` filled from
-- `Layout.tieTreePoints` -- twelve trees placed behind the shooter line on purpose. Milestone 2.1
-- tagged the twelve scattered trunks nearest the line instead; at full size the wood starts beyond
-- the corridor, so the nearest scattered trunk is ~150 studs away and the design's "within 120 studs"
-- (section 4.3) could not hold. A player tied to a spruce 900 studs away is a teleport, not a penalty.
function Markers.tagTieTrees(root: Instance, _config): number
	local tagged = 0
	for _, trunk in ipairs(Props.trunks(root, "TieTrees")) do
		if not CollectionService:HasTag(trunk, Map.TAGS.tree) then
			CollectionService:AddTag(trunk, Map.TAGS.tree)
		end
		-- Counts every tie tree that ends up tagged, not only the ones this call newly tagged:
		-- re-running the step on an unchanged map would otherwise report "0 tie trees tagged".
		tagged += 1
	end
	return tagged
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
