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

-- `material` IS OPTIONAL AND THE DEFAULT IS THE OLD ONE (step B10): every part written before this
-- step keeps `SmoothPlastic`, and the dressed ones name their own wood, plank or grass.
local function makePart(
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	parent: Instance,
	material: Enum.Material?
)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- ONE CLIMB PROMPT (step B10, item 6). It is `makePrompt`'s shape with its own key and its own two
-- words, because the way up is not the way into the menu: the key is DATA (`CLIMB.UP_KEY` /
-- `DOWN_KEY`) and the two must differ on the deck, where both are in reach -- see the note's 8.2.
local function makeClimbPrompt(
	name: string,
	host: BasePart,
	localAt: Vector3,
	action: string,
	key: Enum.KeyCode,
	layout
)
	local at = Instance.new("Attachment")
	at.Name = "RangeClimbAt"
	at.Position = localAt
	at.Parent = host
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.ObjectText = layout.CLIMB.OBJECT_TEXT
	prompt.KeyboardKeyCode = key
	prompt.MaxActivationDistance = layout.CLIMB.MaxActivationDistance
	prompt.HoldDuration = layout.CLIMB.HoldDuration
	prompt.RequiresLineOfSight = false
	prompt.Parent = at
	return prompt
end

-- THE STATION'S NUMBER, DRAWN AND NOT UPLOADED. A `SurfaceGui` on the board's uprange face with one
-- `TextLabel`; `Range.boardText` is the one answer to what it says, so the spec reads the SAME
-- string the player does (note 8.2; L-094's lesson is that an uploaded id needs its own frame).
--   SurfaceGui https://create.roblox.com/docs/reference/engine/classes/SurfaceGui
local function makeBoardFace(host: BasePart, text: string, face: Enum.NormalId, layout)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardFace"
	gui.Face = face
	gui.AlwaysOnTop = false
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 64
	gui.Parent = host
	local label = Instance.new("TextLabel")
	label.Name = "Number"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = layout.HUT.boardTextColor
	label.Parent = gui
	return gui
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
	-- ONE TERRACE WITH THE LODGE, when the row says where to take the level from (step B8). Read
	-- through the SAME ground reader, so there is no second definition of "where is the ground" and
	-- no require edge to `Lobby`. MEASURED in her place 2026-10-29, one reading each: the range
	-- anchor reads 134.87 and the lobby anchor 149.25. Snapped, that is a shelf of 132 against 148 --
	-- a 16-stud step across her walk, which is why the level is taken from the lodge.
	local from = row.shelfFrom
	local measured = if type(from) == "table" then groundAt(from.x, from.z) else groundAt(x, z)
	if measured == nil then
		return nil
	end
	-- SNAPPED DOWN TO THE VOXEL GRID, which is `Lobby.Field.shelfFor` verbatim and for its reason:
	-- a shelf inside a 4-stud band leaves a partial voxel the fill cannot flatten, and FLOORING is
	-- the fixed point -- a second build reads the ground the first one made and lands on it again.
	if row.fill ~= true then
		return measured
	end
	local grid = RangeData.LAYOUT.FILL.GRID_STUDS
	return math.floor((measured :: number) / grid) * grid
end

-- ------------------------------------------------------------- THE TERRACE AND THE EARTH (B8)
--
-- PURE. One rectangle's AIR box and GRASS box: `Lobby.Field`'s exact pair with its two measured
-- lessons -- the air runs from the voxel boundary at or below the shelf (or the hill's own
-- contour survives in that band, task 311's mound) and the grass is a SOLID bank down to
-- `DEPTH_STUDS`, never a slab.
--   Terrain:FillBlock https://create.roblox.com/docs/reference/engine/classes/Terrain#FillBlock
function Build.cutBoxes(rect, shelf: number, layout): (CFrame, Vector3, CFrame, Vector3)
	local grid = layout.FILL.GRID_STUDS
	local bottom = math.floor(shelf / grid) * grid
	local sizeX = rect.maxX - rect.minX
	local sizeZ = rect.maxZ - rect.minZ
	local cx = (rect.minX + rect.maxX) / 2
	local cz = (rect.minZ + rect.maxZ) / 2
	local airH = layout.FILL.CLEAR_STUDS + (shelf - bottom)
	return CFrame.new(cx, bottom + airH / 2, cz),
		Vector3.new(sizeX, airH, sizeZ),
		CFrame.new(cx, shelf - layout.FILL.DEPTH_STUDS / 2, cz),
		Vector3.new(sizeX, layout.FILL.DEPTH_STUDS, sizeZ)
end

-- PURE. THE BERM AS EARTH: a core block plus `slopeSteps` nested bands that batter its UPRANGE
-- face, each band standing from the terrace up to its own top -- so the heap is solid from the
-- ground and the crest is one level line. In the order they are filled.
function Build.bermBoxes(anchor: Vector3, shelf: number, layout, dir: number): { { at: CFrame, size: Vector3 } }
	local at = RangeData.bermPosition(anchor, layout, dir)
	local size = RangeData.bermSizeFor(layout)
	local out = { { at = CFrame.new(at.X, shelf + size.Y / 2, at.Z), size = size } }
	local steps = math.max(0, math.floor(layout.BERM.slopeSteps or 0))
	local run = layout.BERM.slopeRun or 0
	for k = 1, steps do
		local height = size.Y * k / (steps + 1)
		local extra = run * (steps + 1 - k) / steps
		-- THE EXTRA DEPTH IS ALL UPRANGE: the face the shooter sees is battered, the back stays sheer.
		table.insert(out, {
			at = CFrame.new(at.X, shelf + height / 2, at.Z - dir * extra / 2),
			size = Vector3.new(size.X, height, size.Z + extra),
		})
	end
	return out
end

-- THE ONE TERRAIN WRITE IN THIS SYSTEM, and `terrain` is an ARGUMENT so no spec can write a
-- place's ground (design 8.2; `Lobby.Field.fill`'s own discipline). AIR first, then grass, then
-- the earth that stands on it, then the two materials -- in any other order each step eats the
-- one before it. Returns the fill count and the replace count, so which path a build took is a
-- number in `Range.stats()` rather than a belief.
function Build.writeTerrain(terrain: any, anchor: Vector3, shelf: number, row, layout, dir: number): (number, number)
	local fills, replaces = 0, 0
	local chunk = layout.SURFACE.CHUNK_STUDS
	-- CHUNKED ALONG X, `Lobby.Field.chunks`' shape and its reason: `MapGen.Ground` measured a
	-- per-region voxel ceiling in this Studio version, and `FillBlock`'s own is not measured here.
	local function fill(at: CFrame, size: Vector3, material: Enum.Material)
		local left = size.X
		local x = at.Position.X - size.X / 2
		while left > 1e-6 do
			local take = math.min(chunk, left)
			terrain:FillBlock(
				CFrame.new(x + take / 2, at.Position.Y, at.Position.Z),
				Vector3.new(take, size.Y, size.Z),
				material
			)
			fills += 1
			x += take
			left -= take
		end
	end
	local rects = RangeData.cutRects(anchor, layout, dir, row)
	for _, rect in ipairs(rects) do
		local airAt, airSize, grassAt, grassSize = Build.cutBoxes(rect, shelf, layout)
		fill(airAt, airSize, Enum.Material.Air)
		fill(grassAt, grassSize, layout.SURFACE.LANE)
	end
	-- ...THEN THE TWO MATERIALS. `ReplaceMaterial` changes the material of a voxel and NOTHING
	-- else -- no occupancy, no height, no part -- so it can only repaint what the fills shaped.
	-- The lane first (the cover the fill could not reach), the firing line second. NOT because the
	-- first could undo the second -- it is AROUND -> LANE and cannot touch `LINE` -- but because a
	-- repaint whose target is LANE must run after everything that writes LANE (round 1, note).
	--   Terrain:ReplaceMaterial https://create.roblox.com/docs/reference/engine/classes/Terrain#ReplaceMaterial
	--   Region3:ExpandToGrid    https://create.roblox.com/docs/reference/engine/datatypes/Region3#ExpandToGrid
	local skin = layout.FILL.GRID_STUDS
	local function repaint(rect, from: Enum.Material, to: Enum.Material)
		terrain:ReplaceMaterial(
			Region3.new(
				Vector3.new(rect.minX, shelf - skin, rect.minZ),
				Vector3.new(rect.maxX, shelf + skin, rect.maxZ)
			)
				:ExpandToGrid(skin),
			skin,
			from,
			to
		)
		replaces += 1
	end
	for _, rect in ipairs(rects) do
		repaint(rect, layout.SURFACE.AROUND, layout.SURFACE.LANE)
	end
	repaint(RangeData.lineRect(anchor, layout, dir), layout.SURFACE.LANE, layout.SURFACE.LINE)
	-- THE EARTH LAST, AND THAT ORDER MOVED IN STEP B10. The berm and the two banks are now GRASSED
	-- (`SURFACE.BERM`), and the repaint above runs in a band at the shelf over the whole terrace --
	-- so filled BEFORE it, a grassed heap lost the bottom 4 studs of its own skin to
	-- `AROUND -> LANE` and stood in a brown skirt. Nothing in the repaints writes LANE after this,
	-- so the reason the old order existed is satisfied by moving the fills rather than the repaints.
	-- In DEV these are parts and this whole function never runs.
	for _, box in ipairs(Build.bermBoxes(anchor, shelf, layout, dir)) do
		fill(box.at, box.size, layout.SURFACE.BERM)
	end
	for leg = 1, 2 do
		local bank = RangeData.bankPosition(anchor, layout, leg, dir)
		local size = layout.BANK.size
		fill(CFrame.new(bank.X, shelf + size.Y / 2, bank.Z), size, layout.SURFACE.BERM)
	end
	return fills, replaces
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

	-- THE GROUND IS CUT BEFORE ANYTHING IS MEASURED ON IT (step B8). Every part below is laid by
	-- reading `groundAt`, so a terrace written afterwards would move the ground out from under a
	-- row of mats already placed. A nil `terrain`, or a row that asks for no fill, writes nothing --
	-- which is every spec and every DEV run.
	local dir = RangeData.downrangeOf(row)
	local terrainFills, terrainReplaces = 0, 0
	if RangeData.fillsTerrain(row) and opts.terrain ~= nil then
		terrainFills, terrainReplaces = Build.writeTerrain(opts.terrain, anchor, shelf :: number, row, layout, dir)
	end

	local folder = Instance.new("Folder")
	folder.Name = layout.folderName

	-- EVERY PART STANDS FROM THE LOWEST GROUND UNDER ITSELF TO ITS FULL HEIGHT ABOVE THE HIGHEST
	-- (review round 1, finding 1; CLAUDE.md rule E). It is grown downward by the spread under its
	-- own footprint, so nothing floats at the low corner and nothing loses its height at the high
	-- one. With a plate (DEV) the reader is absent and the spread is zero, which is the old shape.
	local function onGround(name: string, size: Vector3, x: number, z: number, color: Color3, material: Enum.Material?)
		local lo, hi = groundUnder(x, z, size, shelf :: number, if row.plate == true then nil else opts.groundAt)
		local height = size.Y + (hi - lo)
		return makePart(
			name,
			Vector3.new(size.X, height, size.Z),
			Vector3.new(x, lo + height / 2, z),
			color,
			folder,
			material
		)
	end

	-- THE GROUND AT ONE POINT, through the same reader and with the same plate rule as `onGround`.
	-- The climb's two ends need a HEIGHT and not a part, and the shelf is one reading at the row's
	-- own point -- 11.6 studs away from the truth across this range (`groundUnder`'s header).
	local function groundAtOr(x: number, z: number): number
		if row.plate == true or opts.groundAt == nil then
			return shelf :: number
		end
		local y = opts.groundAt(x, z)
		return if type(y) == "number" then y :: number else shelf :: number
	end

	-- THE MAT FIRST, so it is the folder's first direct-child BasePart: the harness's stage block
	-- puts the player at a folder's first BasePart plus an offset (design section 11.3), and that
	-- has to be the firing position and not a screen 145 studs downrange.
	-- WHICH WAY IS DOWNRANGE, off the ROW and never off the world's name: +1 in DEV, -1 in Karen's
	-- place, where the lane points south away from the lodge (design 4.2 item 5).
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
		-- PLANKED AND LIGHTER SINCE B10 -- same size, same point, only the skin (note 8.3 L1).
		local bench = RangeData.benchPosition(anchor, spot, layout, dir)
		onGround(
			RangeData.benchName(spot),
			layout.BENCH.size,
			bench.X,
			bench.Z,
			layout.BENCH.color,
			layout.BENCH.material
		)

		-- THE ROOFED FIRING POINT (step B10, item 3; refs 1, 5, 7). Four corner posts up to the
		-- roof's own bottom, the roof over them, and the station's NUMBER on the uprange fascia.
		-- Nothing here is in a line of fire: `Range.sightHalfWidthAt` is the bound and `range.spec`
		-- asserts every post against it.
		local hut = layout.HUT
		local roofAt = RangeData.hutRoofPosition(anchor, spot, layout, dir)
		for corner, hutAt in ipairs(RangeData.hutPostPositions(anchor, spot, layout, dir)) do
			local footY = groundAtOr(hutAt.x, hutAt.z) - 0.3
			local topY = roofAt.Y - hut.roofSize.Y / 2
			local height = math.max(topY - footY, 1)
			makePart(
				RangeData.hutPostName(spot, corner),
				Vector3.new(hut.postSection, height, hut.postSection),
				Vector3.new(hutAt.x, footY + height / 2, hutAt.z),
				hut.postColor,
				folder,
				Enum.Material.Wood
			)
		end
		makePart(RangeData.hutRoofName(spot), hut.roofSize, roofAt, hut.roofColor, folder, Enum.Material.WoodPlanks)
		local boardAt = RangeData.boardPosition(anchor, spot, layout, dir)
		local board = makePart(
			RangeData.boardName(spot),
			hut.boardSize,
			boardAt,
			hut.boardColor,
			folder,
			Enum.Material.SmoothPlastic
		)
		-- BOTH FACES, so the number reads walking in AND standing at the bench. `Front` is -Z and
		-- `Back` is +Z, so which one points uprange is the ROW's business -- and writing both means
		-- no branch on the world's name at all.
		makeBoardFace(board, RangeData.boardText(spot), Enum.NormalId.Front, layout)
		makeBoardFace(board, RangeData.boardText(spot), Enum.NormalId.Back, layout)
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
		local ladder: BasePart? = nil
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
				elseif part.Name == "Ladder" then
					ladder = part
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
				-- THE WAY DOWN, on `CLIMB.DOWN_KEY` (F) over the rail's gap. On the DECK and not on
				-- the rail board, for `makePrompt`'s own stated reason: the deck is the one piece
				-- whose name does not move when `facing` mirrors the rail.
				makeClimbPrompt(
					RangeData.climbPromptName(spot, "down"),
					deck :: BasePart,
					RangeData.downPromptPosition(anchor, spot, layout, dir, deckTop) - (deck :: BasePart).Position,
					layout.CLIMB.DOWN_ACTION,
					layout.CLIMB.DOWN_KEY,
					layout
				)
			end
			-- THE WAY UP, on `CLIMB.UP_KEY` (E) at the ladder's foot (step B10, item 6). B9 measured
			-- TWICE that a real `W` against this `TrussPart` never climbs (`ESCALATE.md`, B9), so the
			-- climb is a prompt and the server moves the body -- `Range.onClimb` is its one handler.
			if ladder ~= nil then
				local foot = RangeData.ladderFootPosition(anchor, spot, layout, dir)
				local point = Vector3.new(foot.X, groundAtOr(foot.X, foot.Z) + layout.CLIMB.footRise, foot.Z)
				makeClimbPrompt(
					RangeData.climbPromptName(spot, "up"),
					ladder :: BasePart,
					point - (ladder :: BasePart).Position,
					layout.CLIMB.UP_ACTION,
					layout.CLIMB.UP_KEY,
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
	-- ...AS PARTS OR AS EARTH, off the ROW and never off the world's name (design 8.1). Where
	-- `berm = "terrain"` the two banks and the berm went into the ground above, and building them
	-- again here would stand a grey box inside a heap of soil.
	local asEarth = RangeData.bermIsTerrain(row)
	if not asEarth then
		for leg = 1, 2 do
			local at = RangeData.bankPosition(anchor, layout, leg, dir)
			onGround(RangeData.bankName(leg), layout.BANK.size, at.X, at.Z, layout.BANK.color, Enum.Material.Grass)
		end
	end

	-- THE BACKSTOP, behind the longest lane: its width is DERIVED so it spans every station's lane
	-- AND both banks (design 5.2), and it stops a stray slug leaving the lobby.
	if not asEarth then
		local berm = RangeData.bermPosition(anchor, layout, dir)
		onGround("Berm", RangeData.bermSizeFor(layout), berm.X, berm.Z, layout.BERM.color, Enum.Material.Grass)
	end

	-- THE MOWN LANE (step B10, item 2): ONE decorative slab of a BasePart's `Grass` -- a flat
	-- texture with NO blades, because blades are the TERRAIN renderer's and that is the whole of
	-- B8's measured objection. `CanCollide` and `CanQuery` are FALSE, so a ray, a bullet, a boar's
	-- route and a man's feet all pass straight through it: nothing about the game moves (8.3 L3).
	local turfRect = RangeData.turfRect(anchor, layout, dir)
	local turf = makePart(
		RangeData.TURF_NAME,
		Vector3.new(turfRect.maxX - turfRect.minX, layout.TURF.thickness, turfRect.maxZ - turfRect.minZ),
		Vector3.new(
			(turfRect.minX + turfRect.maxX) / 2,
			(shelf :: number) + layout.TURF.liftStuds - layout.TURF.thickness / 2,
			(turfRect.minZ + turfRect.maxZ) / 2
		),
		layout.TURF.color,
		folder,
		layout.TURF.material
	)
	turf.CanCollide = false
	turf.CanQuery = false
	turf.CanTouch = false
	turf.CastShadow = false

	-- TIDY EDGES (step B10, item 5; ref-5): a low rail fence down the lot's two long sides, laid on
	-- the BERM'S OWN SPAN in X -- 18 studs outside the corridor, so nothing on it is in a line of
	-- fire. Each post is grown off its own measured ground like every other part here (rule E).
	local fence = layout.FENCE
	local legCount: { [number]: number } = {}
	for _, post in ipairs(RangeData.fencePosts(anchor, layout, dir)) do
		legCount[post.leg] = (legCount[post.leg] or 0) + 1
		onGround(
			RangeData.fencePostName(post.leg, legCount[post.leg]),
			Vector3.new(fence.postSection, fence.postRise, fence.postSection),
			post.x,
			post.z,
			fence.color,
			fence.material
		)
	end
	-- THE RAIL IS NOT LAID ON THE GROUND, so `onGround` is the wrong tool for it: it is one long
	-- board `railRise` ABOVE the ground, and `onGround` grows a part DOWNWARD by the spread under
	-- its own footprint -- which over a 200-stud board would be a wedge. The level is taken at the
	-- line's own middle, which is the whole terrace and flat by construction (`CUT`).
	local fenceSpan = RangeData.fenceSpan(anchor, layout, dir)
	local railZ = (fenceSpan.minZ + fenceSpan.maxZ) / 2
	for leg, x in ipairs({ fenceSpan.minX, fenceSpan.maxX }) do
		makePart(
			RangeData.fenceRailName(leg),
			Vector3.new(fence.railThick, fence.railTall, fenceSpan.maxZ - fenceSpan.minZ),
			Vector3.new(x, groundAtOr(x, railZ) + fence.railRise, railZ),
			fence.color,
			folder,
			fence.material
		)
	end

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
		terrainFills = terrainFills,
		terrainReplaces = terrainReplaces,
		buildMs = math.floor((os.clock() - started) * 1000 + 0.5),
		laneHalf = half,
		downrange = dir,
	}
end

return Build
