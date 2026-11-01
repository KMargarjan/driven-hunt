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
-- NO `HighSeats` HERE SINCE TASK 320: the range builds no treestand, so this module plans no seat
-- (`backups/task-320/`). `ForestTest.Seats` is still the hunt's own reader of it.

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

-- THE STATION'S NUMBER, DRAWN AND NOT UPLOADED. A `SurfaceGui` on one face of the prompt POST with
-- one `TextLabel`; `Range.stationNumberText` is the one answer to what it says, so the spec reads
-- the SAME string the player does (note 8.2; L-094: an uploaded id needs its own frame).
--   SurfaceGui https://create.roblox.com/docs/reference/engine/classes/SurfaceGui
local function makeNumberFace(host: BasePart, text: string, face: Enum.NormalId, layout)
	local gui = Instance.new("SurfaceGui")
	gui.Name = RangeData.NUMBER_GUI_NAME
	gui.Face = face
	gui.AlwaysOnTop = false
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 64
	gui.Parent = host
	local label = Instance.new("TextLabel")
	label.Name = RangeData.NUMBER_LABEL_NAME
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = layout.POST.numberColor
	-- A STROKE, because the post it is drawn on is dark wood and the digit is near-white.
	label.TextStrokeColor3 = layout.POST.numberStroke
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	return gui
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

-- PURE. THE HILL AS BALLS (306m item 1), in the order it is filled: `RangeData.bermBalls`'s
-- inscribed cone of earth, then the scrub clumps on the crest, each carrying the `SURFACE` KEY it
-- is written with so "what is grass and what is bare earth" stays data on the fill.
-- 306l built this from boxes -- one grassed core plus `slopeSteps` bands per column -- and from the
-- bench that read as a castle battlement: square columns with vertical sides and flat tops
-- (306l-R2-AFTER-marker-crop.png). A ball writes PARTIAL voxel occupancy, so the renderer's
-- isosurface is curved; that is the whole reason the shape moved to balls.
--   Terrain:FillBall https://create.roblox.com/docs/reference/engine/classes/Terrain#FillBall
-- Research note: docs/research/2026-10-28-the-range-in-the-lobby.md section 10.
function Build.bermFills(anchor: Vector3, shelf: number, layout, dir: number): { any }
	local out = {}
	for _, ball in ipairs(RangeData.bermBalls(anchor, layout, dir)) do
		out[#out + 1] = {
			at = Vector3.new(ball.x, shelf + ball.rise, ball.z),
			radius = ball.radius,
			surface = ball.surface,
		}
	end
	-- THE SCRUB LAST, so nothing paints over it.
	for _, clump in ipairs(RangeData.bermScrubPoints(anchor, layout, dir)) do
		out[#out + 1] = {
			at = Vector3.new(clump.x, shelf + clump.rise, clump.z),
			radius = clump.radius,
			surface = "SCRUB",
		}
	end
	return out
end

-- THE ONE TERRAIN WRITE IN THIS SYSTEM, and `terrain` is an ARGUMENT so no spec can write a
-- place's ground (design 8.2; `Lobby.Field.fill`'s own discipline). AIR first, then grass, then
-- the terrace's own two repaints, then the banks and the earth that stand on it, then the hill's
-- grass line -- in any other order each step eats the one before it (the order moved in B10 and
-- again in 306m; round 1, note). Returns the fill count and the replace count, so which path a build took is a
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
	-- ...and the same call over an arbitrary box, for the hill's own grass line.
	local function repaintBox(
		minZ: number,
		maxZ: number,
		minX: number,
		maxX: number,
		minY: number,
		maxY: number,
		from: Enum.Material,
		to: Enum.Material
	)
		terrain:ReplaceMaterial(
			Region3.new(Vector3.new(minX, minY, minZ), Vector3.new(maxX, maxY, maxZ)):ExpandToGrid(skin),
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
	-- THE EARTH LAST, AND THAT ORDER MOVED IN STEP B10. The berm and the two banks are BARE EARTH
	-- (`SURFACE.BERM`), and the repaint above runs in a band at the shelf over the whole terrace --
	-- so filled BEFORE it, a grassed heap lost the bottom 4 studs of its own skin to
	-- `AROUND -> LANE` and stood in a brown skirt. Nothing in the repaints writes LANE after this,
	-- so the reason the old order existed is satisfied by moving the fills rather than the repaints.
	-- In DEV these are parts and this whole function never runs.
	-- NO CHUNKING FOR A BALL: `CHUNK_STUDS` exists because a wide `FillBlock` met a per-region
	-- voxel ceiling, and the widest ball here is `(slopeRun + depth)/2` = 8 studs in RADIUS, so 16
	-- across -- a quarter of the 64-stud chunk.
	local function ball(at: Vector3, radius: number, material: Enum.Material)
		terrain:FillBall(at, radius, material)
		fills += 1
	end
	-- THE BANKS BEFORE THE HEAP, so the LAST ball written anywhere is a scrub clump and nothing can
	-- paint over it. Where the bank's mound and the heap's toe overlap, the heap's earth wins, which
	-- is the impact face and is right.
	-- THE TWO SIDE BANKS ARE GRASSED (306l item 2), so they read as spurs of the same hill rather
	-- than as two bare kerbs in front of it. 306m: ROUNDED, and in two chains that run into the
	-- heap's own toe, so neither end is a square block (306m item 2).
	for leg = 1, 2 do
		for _, one in ipairs(RangeData.bankBalls(anchor, layout, leg, dir)) do
			ball(Vector3.new(one.x, shelf + one.rise, one.z), one.radius, layout.SURFACE[one.surface])
		end
	end
	-- THE HILL, ALL OF IT EARTH, THEN REPAINTED (below). A ball is one material, and the crest's
	-- grass / face's earth split runs THROUGH the middle of the crown balls -- so the split is a
	-- `ReplaceMaterial` over the back half and not a second chain of fills.
	for _, one in ipairs(Build.bermFills(anchor, shelf, layout, dir)) do
		ball(one.at, one.radius, layout.SURFACE[one.surface])
	end
	-- ...AND THE GRASSED HALF IS A REPAINT (306m). `ReplaceMaterial` changes a voxel's material and
	-- NOTHING else, so it can split a ball the fills could not: earth uprange of the apex line
	-- (`bermCrestFaceZ`, the impact face) and grass from it back over the crest and the back slope.
	-- FROM `2 * GRID` UP, and that is measured, not tidy: `SURFACE.BERM` and `SURFACE.LANE` are the
	-- SAME material (`Ground`), so a band that reached the shelf would turn the terrace's own
	-- downrange strip to grass. Two voxels up, `ExpandToGrid` cannot reach the terrace skin, and
	-- what stays earth is the bottom 8 studs of the BACK slope -- which no lane can see.
	local apexZ = RangeData.bermCrestFaceZ(anchor, layout, dir)
	local backZ = RangeData.bermPosition(anchor, layout, dir).Z + dir * layout.BERM.depth / 2
	local westX, eastX = RangeData.bermSpanFor(anchor, layout)
	repaintBox(
		math.min(apexZ, backZ),
		math.max(apexZ, backZ),
		westX,
		eastX,
		shelf + 2 * skin,
		shelf + layout.BERM.height + layout.BERM.capRadius + skin,
		layout.SURFACE.BERM,
		layout.SURFACE.HILL
	)
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
		-- THE RECTANGLE IS FLUSH, NOT A STEP (task 322). `onGround` grows a part DOWNWARD from its
		-- own top, so the mat's top stood a full stud over the ground and he stepped up onto it.
		-- Laid like the `TURF` slab instead: the top is `liftStuds` proud of the HIGHEST ground under
		-- its footprint, so no corner is buried and nothing is a kerb. It is still the folder's first
		-- BasePart and still the full 8x8 station box `Range.spotAt` measures.
		local _matLo, matHi =
			groundUnder(at.X, at.Z, layout.MAT.size, shelf :: number, if row.plate == true then nil else opts.groundAt)
		local mat = makePart(
			RangeData.matName(spot),
			layout.MAT.size,
			Vector3.new(at.X, matHi + layout.MAT.liftStuds - layout.MAT.size.Y / 2, at.Z),
			layout.MAT.color,
			folder,
			layout.MAT.material
		)
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
		-- THE STATION'S NUMBER, ON THE POST'S TWO +-Z FACES. The hut's fascia board carried it until
		-- task 322; `Front` is -Z and `Back` is +Z, so writing BOTH means the digit reads walking in
		-- from the lodge whichever way the ROW points and there is no branch on the world's name.
		makeNumberFace(postPart, RangeData.stationNumberText(spot), Enum.NormalId.Front, layout)
		makeNumberFace(postPart, RangeData.stationNumberText(spot), Enum.NormalId.Back, layout)
		table.insert(mats, mat)
	end

	-- NO TREESTANDS ON THE RANGE (task 320). Karen, 2026-10-31: *"and remove towers we dont need
	-- them in shooting range"*. The six decks, their ladders, their `RangeStandPrompt` and the two
	-- climb prompts are gone -- archived in `backups/task-320/`. The ground is the one firing
	-- position, and since task 322 the BENCH REST is gone too (`backups/task-322/`): nothing read
	-- `benchPosition` but the build itself, so it was a prop. `deckTops` stays an EMPTY table and
	-- not a removed field: `Range.onClimb` already refuses a station with no entry and
	-- `Range.spotAt` already answers `bench` -- the POSITION's word, not the part -- without one, so
	-- nothing downstream branches on the removal (design shooting-range-lobby 7.1-7.3, now unbuilt).
	local deckTops: { [number]: number } = {}
	local stands, refusedStands = 0, 0
	local standRefusals: { string } = {}

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
			-- `SURFACE.HILL` for the banks, as on the terrain arm (306l item 2): the heap's grassed
			-- half is its crest, its back and its two side banks.
			onGround(RangeData.bankName(leg), layout.BANK.size, at.X, at.Z, layout.BANK.color, layout.SURFACE.HILL)
		end
	end

	-- THE BACKSTOP, behind the longest lane: its width is DERIVED so it spans every station's lane
	-- AND both banks (design 5.2), and it stops a stray slug leaving the lobby.
	if not asEarth then
		local berm = RangeData.bermPosition(anchor, layout, dir)
		-- `SURFACE.BERM` HERE AND NOT A THIRD THING: in DEV the berm is ONE box and it is the
		-- IMPACT FACE's material, which is the half of the heap a DEV lane ever meets. The terrain
		-- arm writes three materials (306l item 2) and this arm cannot: it has one box.
		onGround("Berm", RangeData.bermSizeFor(layout), berm.X, berm.Z, layout.BERM.color, layout.SURFACE.BERM)
	end

	-- THE MOWN LANE (step B10, item 2): decorative slabs of a BasePart's `Grass` -- a flat texture
	-- with NO blades, because blades are the TERRAIN renderer's and that is the whole of B8's
	-- measured objection. `CanCollide` and `CanQuery` are FALSE, so a ray, a bullet, a boar's route
	-- and a man's feet all pass straight through: nothing about the game moves (note 8.3 L3).
	-- ONE SLAB PER TERRACE RECTANGLE: her place's terrace is two (`cutRects`' keep-out), and a
	-- single slab across both would hang over the lodge terrace's edge.
	for index, rect in ipairs(RangeData.turfSlabs(anchor, layout, dir, row)) do
		local size = Vector3.new(rect.maxX - rect.minX, layout.TURF.thickness, rect.maxZ - rect.minZ)
		local cx, cz = (rect.minX + rect.maxX) / 2, (rect.minZ + rect.maxZ) / 2
		-- ON THE GROUND IT SKINS, not on the shelf: in her place those are 150 and 148, and laid on
		-- the shelf the mown lane was 1.9 studs UNDER the terrain -- invisible, which is exactly
		-- what the first frame from the bench showed (2026-10-29).
		-- ONE READING AT THE SLAB'S OWN CENTRE, and NOT `groundUnder`'s five: this slab is 232 x 158
		-- and its corners sit on the BERM and the BANKS, so the five-sample rule -- written for a
		-- 6-stud bench -- floated the lane 11.7 studs into the air on the next frame. The terrace it
		-- skins is flat by construction (`CUT`), which is the whole reason one reading is enough here.
		local hi = groundAtOr(cx, cz)
		local turf = makePart(
			if index == 1 then RangeData.TURF_NAME else string.format("%s%d", RangeData.TURF_NAME, index),
			size,
			Vector3.new(cx, hi + layout.TURF.liftStuds - layout.TURF.thickness / 2, cz),
			layout.TURF.color,
			folder,
			layout.TURF.material
		)
		turf.CanCollide = false
		turf.CanQuery = false
		turf.CanTouch = false
		turf.CastShadow = false
	end

	-- TIDY EDGES (step B10, item 5): NOT BUILT, AND THAT IS A MEASUREMENT, not an omission.
	-- The lot's two long sides stand 18 studs outside the corridor, which in Karen's place is OFF
	-- the cut terrace and on the hill. Measured there on 2026-10-29 (census, and
	-- `<runs-dir>/306b10-post.luau`): along the east line the BUILD's own ground reader and a plain
	-- terrain raycast DISAGREE by up to 7.5 studs -- reader 159.1, terrain 150.0 at (2775, -3061) --
	-- so a post laid on the reader's answer stands 7.5 studs in the air in the picture. Refusing a
	-- post by footprint SPREAD did not catch it: the two readers disagree about the SURFACE, not
	-- about its slope, and a 0.7-stud footprint has no spread to measure.
	-- A floating post is exactly the defect rule E exists for, so the lot's edge ships as the banks
	-- and the berm alone, and the side line is queued with this measurement.
	-- `Range.fenceRuns` / `fencePosts` / `fencePostName` stay as the arithmetic a later task needs;
	-- `range.spec` asserts the build writes NONE of them, so this is a decision with a case on it.
	local fenceRefused = #RangeData.fencePosts(anchor, layout, dir, row)

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
		fenceRefused = fenceRefused,
		terrainFills = terrainFills,
		terrainReplaces = terrainReplaces,
		buildMs = math.floor((os.clock() - started) * 1000 + 0.5),
		laneHalf = half,
		downrange = dir,
	}
end

return Build
