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
-- Design: docs/design/shooting-range.md sections 4, 4.1 and 11.1, and its delta
-- docs/design/shooting-range-lobby.md 5.1-5.4 and 7.1-7.3 (where every number now comes from).
-- Task 298 step B2; task 306 steps B2 and B3.
--
-- It takes its PARENT as an argument, so a spec builds a whole range into `Instance.new("Folder")`
-- and no spec ever writes `Workspace` (`Lobby.Build.build`'s own shape).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RangeData = require(ReplicatedStorage:WaitForChild("Range"))
-- THE SEAT IS THE HUNT'S OWN SEAT: `HighSeats.plan` is the ONE answer to "what is a seat" and this
-- module only measures the ground under one and parents its pieces -- `ForestTest.Seats`' own split
-- (design shooting-range-lobby 7.1).
local HighSeats = require(ReplicatedStorage:WaitForChild("HighSeats"))

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

-- ONE PART FROM ONE `HighSeats.Piece`, and every flag comes from the plan rather than from a
-- default here -- `ForestTest.Seats`' own `build`, which is the only other writer of a seat.
-- The class is the plan's: a `TrussPart` is what a Humanoid climbs, with no script and no key.
local function makePiece(spec: any, parent: Instance): BasePart
	local part = Instance.new(spec.class) :: any
	part.Name = spec.name
	part.Size = spec.size
	part.CFrame = spec.cframe
	part.Anchored = true
	part.CanCollide = spec.canCollide
	part.CanQuery = spec.canQuery
	part.CanTouch = false
	part.CastShadow = spec.castShadow
	part.Color = spec.color
	part.Material = spec.material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if spec.style ~= nil then
		part.Style = spec.style
	end
	part.Parent = parent
	return part :: BasePart
end

-- ONE PROMPT ON AN ATTACHMENT, which is `Lobby.Build.shopPrompt`'s shape and the reason the two
-- range prompts are found by NAME and nothing downstream knows where they hang.
local function makePrompt(name: string, host: BasePart, localAt: Vector3, layout)
	local at = Instance.new("Attachment")
	at.Name = "RangePromptAt"
	at.Position = localAt
	at.Parent = host
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = layout.PROMPT.ActionText
	prompt.ObjectText = layout.PROMPT.ObjectText
	prompt.MaxActivationDistance = layout.PROMPT.MaxActivationDistance
	prompt.HoldDuration = layout.PROMPT.HoldDuration
	prompt.RequiresLineOfSight = false
	prompt.Parent = at
	return prompt
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
		local mat = onGround(RangeData.matName(spot), layout.MAT.size, at.X, at.Z, layout.MAT.color)
		-- THE POST, AND THE PROMPT ON TOP OF IT, NOT ON THE FLOOR. A prompt lying on the 8x8 mat is
		-- off screen whenever she looks down the lane, and E then does nothing (Director's
		-- real-key proof, 2026-10-28). `Lobby.Build.shopPrompt`'s shape: a part at chest height,
		-- with the prompt on an attachment, found by NAME so nothing downstream changes.
		local post = RangeData.promptPosition(anchor, spot, layout, dir, RangeData.POSITION.BENCH)
		local postPart = onGround(RangeData.postName(spot), layout.POST.size, post.X, post.Z, layout.POST.color)
		makePrompt(
			RangeData.promptName(spot, RangeData.POSITION.BENCH),
			postPart,
			Vector3.new(0, postPart.Size.Y / 2, 0),
			layout
		)
		-- THE BENCH REST, downrange of the mat: the ground firing position's own 0.7-0.8 m top.
		local bench = RangeData.benchPosition(anchor, spot, layout, dir)
		onGround(RangeData.benchName(spot), layout.BENCH.size, bench.X, bench.Z, layout.BENCH.color)
		table.insert(mats, mat)
	end

	-- THE SECOND FIRING POSITION, STATION BY STATION (design 7.1-7.3). The ground under the seat's
	-- OWN five footprint points is measured and handed to `HighSeats.plan`, which REFUSES a seat on
	-- ground it cannot build on (`MAX_FOOT_SPREAD_STUDS` 4.0) -- and a refused station is a bench
	-- only, as DATA: `deckTops[spot]` is simply absent and `Range.spotAt` can then never answer
	-- `treestand` there. No branch anywhere.
	local facing = RangeData.standFacing(layout, dir)
	local samples = HighSeats.footprint(facing)
	local deckTops: { [number]: number } = {}
	local stands, refusedStands = 0, 0
	local standRefusals: { string } = {}
	for spot = 1, layout.SPOT_COUNT do
		local at = RangeData.standPosition(anchor, spot, layout, dir)
		local grounds: { number? } = {}
		for index, offset in ipairs(samples) do
			if row.plate == true then
				-- A PLATE IS ONE FLAT SHELF, so the five readings are one number and the spread is
				-- zero: the DEV arm takes no ray at all (`shelfAt`'s own rule).
				grounds[index] = shelf
			elseif opts.groundAt ~= nil then
				grounds[index] = opts.groundAt(at.X + offset.dx, at.Z + offset.dz)
			end
		end
		-- `plan` reads the stand point's X and Z only -- every height it builds comes from the five
		-- readings -- so the shelf in `at.Y` changes nothing it lays.
		local pieces, why = HighSeats.plan(at, grounds, facing)
		if pieces == nil then
			refusedStands += 1
			table.insert(standRefusals, string.format("%d: %s", spot, tostring(why)))
		else
			local seat = Instance.new("Folder")
			seat.Name = RangeData.standName(spot)
			local deck: BasePart? = nil
			for _, spec in ipairs(pieces :: { any }) do
				local part = makePiece(spec, seat)
				if part.Name == "Deck" then
					deck = part
				end
			end
			seat.Parent = folder
			stands += 1
			local deckTop = HighSeats.deckTopFor(grounds)
			if deckTop ~= nil then
				deckTops[spot] = deckTop :: number
			end
			-- THE STAND'S PROMPT, at the rail's own top on the UPRANGE face. It hangs on the DECK
			-- and not on the rail board, which is a stated deviation from design 7.3: the deck is
			-- the one piece whose NAME does not move when `facing` mirrors the rail, and
			-- `Range.promptPointOf` reads the attachment's WorldPosition -- so the prompt's world
			-- point is the design's number either way, and `range.spec` asserts that identity.
			if deck ~= nil and deckTop ~= nil then
				local point = Vector3.new(
					(deck :: BasePart).Position.X,
					(deckTop :: number) + layout.STAND.promptRise,
					(deck :: BasePart).Position.Z - dir * HighSeats.DIMS.RAIL_PLANE_STUDS
				)
				makePrompt(
					RangeData.promptName(spot, RangeData.POSITION.TREESTAND),
					deck :: BasePart,
					point - (deck :: BasePart).Position,
					layout
				)
			end
		end
	end

	local half = RangeData.laneLength(layout) / 2
	local spots = RangeData.spotSpan(layout)
	local deepest = RangeData.distanceMax(layout)

	-- THE GROUND PLATE, DEV only: the range's own shelf, so the harness needs no terrain and no
	-- measured forest clearing to run a lane. It is sized to SIX stations and the LONGEST lane, and
	-- centred on the stations like the berm -- centred on the anchor it would span 1062..1338 and
	-- stop 38 studs short of station 6's own bank (`range.spec` asserts every part is over it).
	if row.plate == true then
		local plate = layout.PLATE
		local spanX = math.max(spots + RangeData.laneLength(layout), plate.minSpan) + plate.marginStuds
		local spanZ = deepest + plate.marginStuds
		makePart(
			"Plate",
			Vector3.new(spanX, plate.thickness, spanZ),
			Vector3.new(anchor.X + spots / 2, shelf - plate.thickness / 2, anchor.Z + dir * deepest / 2),
			plate.color,
			folder
		)
	end

	-- THE TWO COVER BANKS, one BEYOND each end of the SHARED corridor (design 5.3): ISSF hides the
	-- turn-around, because a visible 180-degree turn is not a crossing animal. `bankPosition` and
	-- not `laneEnds`: a bank ON the end is a wall the target walks into (measured in DEV).
	for leg = 1, 2 do
		local at = RangeData.bankPosition(anchor, layout, leg, dir)
		onGround(RangeData.bankName(leg), layout.BANK.size, at.X, at.Z, layout.BANK.color)
	end

	-- THE BACKSTOP, behind the longest lane: its width is DERIVED so it spans every station's lane
	-- AND both banks (design 5.2), and it stops a stray slug leaving the lobby.
	local berm = RangeData.bermPosition(anchor, layout, dir)
	onGround("Berm", RangeData.bermSizeFor(layout), berm.X, berm.Z, layout.BERM.color)

	-- THE PARENT, LAST.
	folder.Parent = parent

	-- EVERY PART, INCLUDING THE SEATS' -- they live in a folder of their own per station, so a
	-- direct-child count would report 22 for a range of 106 and the `MAX_PARTS` bound would be
	-- measuring nothing.
	local parts = 0
	for _, child in ipairs(folder:GetDescendants()) do
		if child:IsA("BasePart") then
			parts += 1
		end
	end

	return {
		folder = folder,
		anchor = anchor,
		shelf = shelf,
		mats = mats,
		deckTops = deckTops,
		stands = stands,
		refusedStands = refusedStands,
		standRefusals = standRefusals,
		parts = parts,
		buildMs = math.floor((os.clock() - started) * 1000 + 0.5),
		laneHalf = half,
		downrange = dir,
	}
end

return Build
