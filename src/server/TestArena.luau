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

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- The tag strings come from the contract, not from here (Task 43): the arena and the generated map
-- must tag with the same five strings or Match.Markers finds one world and not the other, and a typo
-- in a second copy yields a silently empty GetTagged.
local Map = require(ReplicatedStorage:WaitForChild("Map"))

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

	-- THE DRIVE'S GAMEPLAY MARKERS (docs/design/drive.md section 6.1), tagged rather than named:
	-- ServerScriptService.Match.Markers asks CollectionService for them and never looks at a name,
	-- so the Milestone 2 map generator can place the same tags anywhere and nothing else changes.
	-- Laid out against Boar.CONFIG.field: the exit line is z = -190, so the shooter line sits 40
	-- studs in front of it and a boar that beats the line runs on behind the shooters rather than
	-- vanishing in their faces.
	drive = {
		postCount = 8,
		postSpacing = 40, -- x = -140 .. +140
		postZ = -150,
		postSize = Vector3.new(4, 6, 4),
		postColor = Color3.fromRGB(120, 95, 70),

		lineZ = -150,
		lineSize = Vector3.new(320, 1, 1),
		lineColor = Color3.fromRGB(200, 170, 90),

		driverStartZ = 170,
		driverStartSize = Vector3.new(120, 1, 12),
		driverStartColor = Color3.fromRGB(110, 140, 110),

		boarSpawnZ = 120,
		boarSpawnX = { -120, -40, 40, 120 },
		boarSpawnSize = Vector3.new(6, 1, 6),
		boarSpawnColor = Color3.fromRGB(150, 130, 110),

		-- The four corner pillars are re-used as the trees a punished shooter is tied to (1.7b).
		-- Tagged, not moved: nothing here creates a second pillar.
		treeBlocks = { "PillarNW", "PillarNE", "PillarSW", "PillarSE" },

		tags = {
			post = Map.TAGS.shooterPost,
			line = Map.TAGS.driveLine,
			driverStart = Map.TAGS.driverStart,
			boarSpawn = Map.TAGS.boarSpawn,
			tree = Map.TAGS.tree,
		},
	},
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

-- The drive's markers. Every one is tagged, and the tag is the contract -- the names are for a
-- human reading the explorer. The drive LINE is the one that has to be built with a CFrame rather
-- than a Position: its LookVector must point at the DRIVERS (+Z), because that is the direction the
-- weapon's SafetyArc measures against, and a line pointing the wrong way would make the safety rule
-- fire on exactly the wrong shots. tests/server/test_arena.spec.luau asserts it.
local function buildDriveMarkers(folder: Folder, built: { [string]: BasePart })
	local ground = LAYOUT.ground
	local drive = LAYOUT.drive

	for index = 1, drive.postCount do
		local x = (index - (drive.postCount + 1) / 2) * drive.postSpacing
		local post = makePart(
			string.format("ShooterPost%d", index),
			drive.postSize,
			Vector3.new(x, ground.top + drive.postSize.Y / 2, drive.postZ),
			drive.postColor,
			folder
		)
		CollectionService:AddTag(post, drive.tags.post)
	end

	local line = makePart(
		"DriveLine",
		drive.lineSize,
		Vector3.new(0, ground.top + drive.lineSize.Y / 2, drive.lineZ),
		drive.lineColor,
		folder
	)
	local at = line.Position
	line.CFrame = CFrame.lookAt(at, at + Vector3.new(0, 0, 1)) -- LookVector -> +Z, toward the drivers
	CollectionService:AddTag(line, drive.tags.line)

	local start = makePart(
		"DriverStart",
		drive.driverStartSize,
		Vector3.new(0, ground.top + drive.driverStartSize.Y / 2, drive.driverStartZ),
		drive.driverStartColor,
		folder
	)
	CollectionService:AddTag(start, drive.tags.driverStart)

	for index, x in ipairs(drive.boarSpawnX) do
		local spawnPart = makePart(
			string.format("BoarSpawn%d", index),
			drive.boarSpawnSize,
			Vector3.new(x, ground.top + drive.boarSpawnSize.Y / 2, drive.boarSpawnZ),
			drive.boarSpawnColor,
			folder
		)
		CollectionService:AddTag(spawnPart, drive.tags.boarSpawn)
	end

	for _, name in ipairs(drive.treeBlocks) do
		local pillar = built[name]
		if pillar then
			CollectionService:AddTag(pillar, drive.tags.tree)
		end
	end
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

	local built = {}
	for _, block in ipairs(LAYOUT.blocks) do
		built[block.name] = makePart(
			block.name,
			block.size,
			Vector3.new(block.x, ground.top + block.size.Y / 2, block.z),
			LAYOUT.blockColor,
			folder
		)
	end

	buildDriveMarkers(folder, built)

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
