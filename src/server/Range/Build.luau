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

-- THE GROUND UNDER ONE PART'S OWN FOOTPRINT, as a low/high pair: five samples (four corners and
-- the centre) through the world's own reader. ONE read at the anchor is not enough -- the measured
-- spread over this footprint is 11.6 studs, so a berm 137 studs downrange of that read would float
-- or be buried (review round 1, finding 1).
local function groundUnder(centreX: number, centreZ: number, size: Vector3, fallback: number, groundAt)
	local lo, hi = fallback, fallback
	if groundAt == nil then
		return lo, hi
	end
	local halfX = size.X / 2
	local halfZ = size.Z / 2
	local first = true
	for _, at in ipairs({
		{ centreX, centreZ },
		{ centreX - halfX, centreZ - halfZ },
		{ centreX - halfX, centreZ + halfZ },
		{ centreX + halfX, centreZ - halfZ },
		{ centreX + halfX, centreZ + halfZ },
	}) do
		local y = groundAt(at[1], at[2])
		if type(y) == "number" then
			if first then
				lo, hi = y, y
				first = false
			else
				lo = math.min(lo, y)
				hi = math.max(hi, y)
			end
		end
	end
	return lo, hi
end

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

	-- EVERY PART STANDS FROM THE LOWEST GROUND UNDER ITSELF TO ITS FULL HEIGHT ABOVE THE HIGHEST
	-- (review round 1, finding 1; CLAUDE.md rule E). It is grown downward by the spread under its
	-- own footprint, so nothing floats at the low corner and nothing loses its height at the high
	-- one. With a plate (DEV) the reader is absent and the spread is zero, which is the old shape.
	local function onGround(name: string, size: Vector3, x: number, z: number, color: Color3)
		local lo, hi = groundUnder(x, z, size, shelf :: number, if row.plate == true then nil else opts.groundAt)
		local height = size.Y + (hi - lo)
		return makePart(name, Vector3.new(size.X, height, size.Z), Vector3.new(x, lo + height / 2, z), color, folder)
	end

	-- THE MAT FIRST, so it is the folder's first direct-child BasePart: the harness's stage block
	-- puts the player at a folder's first BasePart plus an offset (design section 11.3), and that
	-- has to be the firing position and not a screen 145 studs downrange.
	-- WHICH WAY IS DOWNRANGE, off the ROW and never off the world's name: +1 in DEV, -1 in Karen's
	-- place, where the lane points south away from the lodge (design 4.2 item 5).
	local dir = RangeData.downrangeOf(row)
	local mats = {}
	for spot = 1, layout.SPOT_COUNT do
		local at = RangeData.matPosition(anchor, spot, layout)
		local mat = onGround(
			layout.SPOT_COUNT == 1 and RangeData.MAT_NAME or string.format("%s%d", RangeData.MAT_NAME, spot),
			layout.MAT.size,
			at.X,
			at.Z,
			layout.MAT.color
		)
		-- THE POST, AND THE PROMPT ON TOP OF IT, NOT ON THE FLOOR. A prompt lying on the 8x8 mat is
		-- off screen whenever she looks down the lane, and E then does nothing (Director's
		-- real-key proof, 2026-10-28). `Lobby.Build.shopPrompt`'s shape: a part at chest height,
		-- with the prompt on an attachment, found by NAME so nothing downstream changes.
		local post = RangeData.promptPosition(anchor, spot, layout, dir)
		local postPart = onGround(
			layout.SPOT_COUNT == 1 and "Post" or string.format("Post%d", spot),
			layout.POST.size,
			post.X,
			post.Z,
			layout.POST.color
		)
		local at0 = Instance.new("Attachment")
		at0.Name = "RangePromptAt"
		at0.Position = Vector3.new(0, postPart.Size.Y / 2, 0)
		at0.Parent = postPart
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = if layout.SPOT_COUNT == 1
			then RangeData.PROMPT_NAME
			else string.format("%s%d", RangeData.PROMPT_NAME, spot)
		prompt.ActionText = layout.PROMPT.ActionText
		prompt.ObjectText = layout.PROMPT.ObjectText
		prompt.MaxActivationDistance = layout.PROMPT.MaxActivationDistance
		prompt.HoldDuration = layout.PROMPT.HoldDuration
		prompt.RequiresLineOfSight = false
		prompt.Parent = at0
		table.insert(mats, mat)
	end

	local lane = RangeData.laneCentre(anchor, layout, dir)
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
			Vector3.new(anchor.X, shelf - plate.thickness / 2, anchor.Z + dir * layout.DISTANCE_STUDS / 2),
			plate.color,
			folder
		)
	end

	-- THE TWO SCREENS, one BEYOND each end of the lane: ISSF hides the turn-around, because a
	-- visible 180-degree turn is not a crossing animal. `screenPosition` and not `laneEnds`: a
	-- screen ON the end is a wall the target walks into (measured in DEV, section 4.1's row).
	for leg = 1, 2 do
		local at = RangeData.screenPosition(anchor, layout, leg, dir)
		onGround(if leg == 1 then "ScreenEast" else "ScreenWest", layout.SCREEN.size, at.X, at.Z, layout.SCREEN.color)
	end

	-- THE BACKSTOP, behind the lane: a real range's berm, and it stops a stray slug leaving the
	-- lobby.
	onGround("Berm", layout.BERM.size, anchor.X, lane.Z + dir * layout.BERM.behindStuds, layout.BERM.color)

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
		downrange = dir,
	}
end

return Build
