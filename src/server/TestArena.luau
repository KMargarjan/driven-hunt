-- TestArena: the grey-box test area for Milestone 1 (ROADMAP.md step 1.1). The first game geometry.
--
-- Pattern: world geometry built from code into ONE Workspace folder, so the Milestone 2 map generator
-- can replace the whole area by swapping that folder. Nothing is built by hand in Studio, so the
-- layout lives in a diff (PROJECT_CONTEXT.md: "Code on disk, in git, reviewed as a diff").
-- Construction is the plain Roblox idiom: Instance.new, Anchored parts, parent set last.
--   https://create.roblox.com/docs/reference/engine/classes/Instance
--   https://create.roblox.com/docs/reference/engine/classes/BasePart#Anchored
--   https://create.roblox.com/docs/reference/engine/classes/SpawnLocation
--
-- No research note (CLAUDE.md rule 1): trivial throwaway geometry with no external pattern to borrow,
-- replaced by the map generator in Milestone 2. Director decision, Task 17.
--
-- Owner (rule 3): this module is the only writer of Workspace.TestArena. See GAME_DESIGN.md
-- "System owners". It never touches anything else in Workspace, and never deletes (rule 7).
-- Since Task 22 the arena is the only thing in Workspace: Karen had the place's default Baseplate
-- and SpawnLocation moved into ServerStorage.Archive (not deleted), because the Baseplate's top
-- face is coplanar with this plate's and z-fought, and a second spawn made spawning random.
-- Record: backups/2026-09-25_workspace-defaults.md.

local Workspace = game:GetService("Workspace")

-- Every dimension of the arena is here. Positions are the centre in X/Z; Y is derived, so every
-- block rests on the ground surface and nothing has to be kept in sync by hand.
local LAYOUT = {
	folderName = "TestArena",

	ground = {
		span = 400, -- studs, X and Z
		thickness = 4,
		top = 0, -- y of the walkable surface
		color = Color3.fromRGB(150, 150, 150),
	},

	blockColor = Color3.fromRGB(110, 110, 110),

	-- Cover: low walls to crouch behind, tall pillars to break sight lines. Spread over the area and
	-- kept clear of the spawn. Each entry's footprint must sit inside the ground plate; the spec
	-- (tests/server/test_arena.spec.luau) checks that independently.
	blocks = {
		{ name = "WallWest", size = Vector3.new(80, 8, 4), x = -60, z = -100 },
		{ name = "WallEast", size = Vector3.new(4, 8, 80), x = 90, z = 40 },
		{ name = "WallNorth", size = Vector3.new(60, 8, 4), x = 120, z = -140 },
		{ name = "PillarNW", size = Vector3.new(8, 24, 8), x = -150, z = -150 },
		{ name = "PillarNE", size = Vector3.new(8, 24, 8), x = 150, z = -150 },
		{ name = "PillarSW", size = Vector3.new(8, 24, 8), x = -150, z = 150 },
		{ name = "PillarSE", size = Vector3.new(8, 24, 8), x = 150, z = 150 },
		{ name = "PillarMid", size = Vector3.new(8, 24, 8), x = 40, z = -40 },
	},

	-- Near the south edge, looking back across the area.
	spawn = { name = "ArenaSpawn", size = Vector3.new(12, 1, 12), x = 0, z = 170 },
}

local TestArena = {}

TestArena.LAYOUT = LAYOUT

local function makePart(name, size, position, color, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Builds the arena under `parent` (default Workspace) and returns the folder. Idempotent: if the
-- folder is already there it is returned untouched, so a second call cannot produce duplicates and
-- nothing is ever deleted (rule 7).
function TestArena.build(parent)
	local root = parent or Workspace

	local existing = root:FindFirstChild(LAYOUT.folderName)
	if existing then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = LAYOUT.folderName

	local ground = LAYOUT.ground
	makePart(
		"Ground",
		Vector3.new(ground.span, ground.thickness, ground.span),
		Vector3.new(0, ground.top - ground.thickness / 2, 0),
		ground.color,
		folder
	)

	for _, block in ipairs(LAYOUT.blocks) do
		makePart(
			block.name,
			block.size,
			Vector3.new(block.x, ground.top + block.size.Y / 2, block.z),
			LAYOUT.blockColor,
			folder
		)
	end

	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = LAYOUT.spawn.name
	spawnPad.Size = LAYOUT.spawn.size
	spawnPad.Position = Vector3.new(LAYOUT.spawn.x, ground.top + LAYOUT.spawn.size.Y / 2, LAYOUT.spawn.z)
	spawnPad.Anchored = true
	spawnPad.Neutral = true
	spawnPad.Enabled = true
	spawnPad.TopSurface = Enum.SurfaceType.Smooth
	spawnPad.BottomSurface = Enum.SurfaceType.Smooth
	spawnPad.Parent = folder

	-- Parent last: one replication step for the whole arena.
	folder.Parent = root

	return folder
end

return TestArena
