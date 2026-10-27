-- Range.Build: the ONE writer of every Instance under `Workspace.Range` (CLAUDE.md rule 3). It is
-- called only by `ServerScriptService.Range`, its owner.
--
-- Pattern: world geometry built from code into ONE folder, every dimension in one table
-- (`src/server/TestArena.luau`), `Anchored` parts and THE PARENT SET LAST -- one replication step
-- for the whole range. Parts are laid on the ground that is MEASURED and not on the shelf the
-- arithmetic predicts (`src/server/Lobby/init.luau`'s `groundAt` seam: without it four pads
-- *"sat 0.17 studs UNDER the terrain"*).
--   https://create.roblox.com/docs/reference/engine/classes/BasePart#Anchored
--   https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt
-- Design: docs/design/shooting-range.md sections 4, 4.1 and 11.1. Task 298, step B2.
--
-- It takes its PARENT as an argument, so a spec builds a whole range into `Instance.new("Folder")`
-- and no spec ever writes `Workspace` (`Lobby.Build.build`'s own shape).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RangeData = require(ReplicatedStorage:WaitForChild("Range"))

local Build = {}

local function makePart(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance)
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

-- WHERE THE SHELF IS, per the row's one DATA field. `plate = true` lays an anchored plate and the
-- shelf is its top (`TestArena.LAYOUT.ground`'s pattern: no terrain, no raycast, no measurement);
-- `plate = false` reads the world's ONE ground reader at that point. `plate` is data, not a branch
-- in the caller.
function Build.shelfAt(x: number, z: number, row, groundAt: ((number, number) -> number?)?): number?
	if row == nil then
		return nil
	end
	if row.plate == true then
		return row.y or 0
	end
	if groundAt == nil then
		return nil
	end
	return groundAt(x, z)
end

-- Builds the range under `parent` and returns the folder plus what it cost. Returns nil and a
-- reason for a range that cannot be laid -- no row, no ground reader in a world with no plate, or a
-- folder of that name already there (so two `build` calls can never make two ranges).
function Build.build(opts)
	local started = os.clock()
	local parent = opts.parent
	local row = opts.row
	local layout = opts.layout or RangeData.LAYOUT
	if parent == nil then
		return nil, "no parent"
	end
	if row == nil then
		return nil, "no anchor row"
	end
	if parent:FindFirstChild(layout.folderName) ~= nil then
		return nil, "already built"
	end

	local shelf = Build.shelfAt(row.x, row.z, row, opts.groundAt)
	if shelf == nil then
		return nil, "no ground under the range"
	end
	local anchor = Vector3.new(row.x, shelf, row.z)

	local folder = Instance.new("Folder")
	folder.Name = layout.folderName

	-- THE MAT FIRST, so it is the folder's first direct-child BasePart: the harness's stage block
	-- puts the player at a folder's first BasePart plus an offset (design section 11.3), and that
	-- has to be the firing position and not a screen 145 studs downrange.
	local mats = {}
	for spot = 1, layout.SPOT_COUNT do
		local at = RangeData.matPosition(anchor, spot, layout)
		local mat = makePart(
			layout.SPOT_COUNT == 1 and RangeData.MAT_NAME or string.format("%s%d", RangeData.MAT_NAME, spot),
			layout.MAT.size,
			Vector3.new(at.X, shelf + layout.MAT.size.Y / 2, at.Z),
			layout.MAT.color,
			folder
		)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = if layout.SPOT_COUNT == 1
			then RangeData.PROMPT_NAME
			else string.format("%s%d", RangeData.PROMPT_NAME, spot)
		prompt.ActionText = layout.PROMPT.ActionText
		prompt.ObjectText = layout.PROMPT.ObjectText
		prompt.MaxActivationDistance = layout.PROMPT.MaxActivationDistance
		prompt.HoldDuration = layout.PROMPT.HoldDuration
		prompt.RequiresLineOfSight = false
		prompt.Parent = mat
		table.insert(mats, mat)
	end

	local lane = RangeData.laneCentre(anchor, layout)
	local half = RangeData.laneLength(layout) / 2

	-- THE GROUND PLATE, DEV only: the range's own shelf, so the harness needs no terrain and no
	-- measured forest clearing to run a lane.
	if row.plate == true then
		local plate = layout.PLATE
		local spanX = math.max(RangeData.laneLength(layout), plate.minSpan) + plate.marginStuds
		local spanZ = layout.DISTANCE_STUDS + plate.marginStuds
		makePart(
			"Plate",
			Vector3.new(spanX, plate.thickness, spanZ),
			Vector3.new(anchor.X, shelf - plate.thickness / 2, anchor.Z + layout.DISTANCE_STUDS / 2),
			plate.color,
			folder
		)
	end

	-- THE TWO SCREENS, one at each end of the lane: ISSF hides the turn-around, because a visible
	-- 180-degree turn is not a crossing animal.
	for leg = 1, 2 do
		local at = RangeData.laneEnds(anchor, layout, leg)
		makePart(
			if leg == 1 then "ScreenEast" else "ScreenWest",
			layout.SCREEN.size,
			Vector3.new(at.X, shelf + layout.SCREEN.size.Y / 2, at.Z),
			layout.SCREEN.color,
			folder
		)
	end

	-- THE BACKSTOP, behind the lane: a real range's berm, and it stops a stray slug leaving the
	-- lobby.
	makePart(
		"Berm",
		layout.BERM.size,
		Vector3.new(anchor.X, shelf + layout.BERM.size.Y / 2, lane.Z + layout.BERM.behindStuds),
		layout.BERM.color,
		folder
	)

	-- THE PARENT, LAST.
	folder.Parent = parent

	local parts = 0
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") then
			parts += 1
		end
	end

	return {
		folder = folder,
		anchor = anchor,
		shelf = shelf,
		mats = mats,
		parts = parts,
		buildMs = math.floor((os.clock() - started) * 1000 + 0.5),
		laneHalf = half,
	}
end

return Build
