--!strict
-- Hud.ShopDisplay: THE PICTURE IN THE SHOP WINDOW. One model per catalogue item, built on this
-- client, and the pure arithmetic that frames it in a `ViewportFrame` (task 196).
--
-- KAREN, 2026-10-15 ~17:40: *"menus for buying things has to be better more nicer like side menu
-- with click and then shows in right side image and explanation what is that"*. The IMAGE is this
-- file. It is a real model under a real camera rather than an upload, so there is nothing to
-- moderate, nothing to pay for and nothing to wait for -- and the rifle in the window is THE RIFLE,
-- drawn from the same measured geometry the gun in your hands is drawn from.
--
--   ViewportFrame  https://create.roblox.com/docs/reference/engine/classes/ViewportFrame
--     A `ViewportFrame` renders its own descendant parts through its own `CurrentCamera`, with its
--     own light direction and ambient colour. Mesh parts, colours and materials render; Terrain,
--     particles and `SurfaceGui` do NOT -- which is why the licence card below is drawn out of
--     coloured blocks rather than out of text on a surface.
--
-- THIS REPO HAS TWICE DECIDED AGAINST A `ViewportFrame` AND NEITHER REASON APPLIES HERE.
-- `Hud.MapUi` refused one because *"a `ViewportFrame` cannot render Terrain"* and a map is terrain;
-- `Hud.ReportPanel` refused one because a 104-px boar does not need a camera and *"a `ViewportFrame`
-- per row would be eight of them"*. This is ONE viewport, for the ONE selected item, alive only
-- while the panel is open -- and what it has to show is a model, which is the one thing a frame and
-- a `UICorner` cannot draw.
--
-- IT IS A DRAWER AND NOT A SECOND OPINION. The rifle's shape is `Rifle.Geometry.pieces` -- the SAME
-- pure piece list `Camera.Viewmodel` draws in the player's hands and `Weapon.Hardware` draws on the
-- Tool in the world. That makes this the THIRD drawer of one geometry, which is the arrangement
-- those two already established (one pure list, one drawing per view) and not a third source of the
-- shape. Nothing here invents a measurement of the gun.
--
-- WHAT IT READS OFF THE SHARED CATALOGUE, and why that is not the panel deciding anything: the hat's
-- COLOUR, out of `Shop.ROWS[id].grants.hatColor`. A colour cannot travel as a `WireRow` field the
-- panel prints, and it decides nothing about money -- `buyable`, the price and every badge still
-- arrive from the server and are still the only things the buttons read (`ShopPanel`'s own rule).
--
-- Design: docs/design/shop.md (section 5)
-- Note:   docs/research/2026-10-15-shop-window.md
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lever = require(ReplicatedStorage:WaitForChild("Lever"))
local LeverGeometry = require(ReplicatedStorage:WaitForChild("Lever"):WaitForChild("Geometry"))
local RifleGeometry = require(ReplicatedStorage:WaitForChild("Rifle"):WaitForChild("Geometry"))
local ShopData = require(ReplicatedStorage:WaitForChild("Shop"))

local ShopDisplay = {}

-- ---------------------------------------------------------------- the camera
--
-- A NARROW LENS, because a shop window is a photograph and not a point of view: at 70 degrees a
-- rifle 2 studs from the glass bends like a fish-eye, and at 28 it reads as a catalogue picture.
ShopDisplay.FOV_DEG = 28
-- HOW MUCH AIR AROUND THE THING, as a multiplier on what the lens has to hold. 1.15 leaves a thin
-- margin on the long axis without making the item small.
ShopDisplay.PAD = 1.12
-- SLOWLY, AND ONE REVOLUTION IN EIGHTEEN SECONDS (the Designer's spec, 2026-10-16, section 6.4:
-- *"calm enough to read"*). A turn you can read is a turn you do not notice.
ShopDisplay.SPIN_DEG_PER_S = 20
-- WARMER THAN THE FIRST BUILD'S, and the reason is in the spec: *"every item in this shop is wood,
-- brass, card or cloth"*. A cold grey ambient made all four look like plastic.
ShopDisplay.LIGHT_DIRECTION = Vector3.new(-0.42, -1, -0.55)
ShopDisplay.LIGHT_COLOR = Color3.fromHex("FFF8EC")
ShopDisplay.AMBIENT = Color3.fromHex("6E6A62")

-- WHERE THE CAMERA STANDS, in degrees around the item and degrees above it, per kind of thing: a
-- rifle is a SILHOUETTE and is photographed from its side, a hat and a box are photographed from
-- three-quarters on, a card is photographed nearly face-on or it is a line.
--
-- A VIEW ALSO SAYS HOW THE ITEM MOVES. A solid ORBITS; a flat card ROCKS, and that is an engine
-- fact rather than a preference (spec 6.4): *"a flat card on a full orbit goes edge-on twice a
-- revolution and disappears; a nine-second sway never does"*.
export type View = {
	yawDeg: number,
	pitchDeg: number,
	pad: number?,
	rockDegrees: number?,
	rockSeconds: number?,
}

local RIFLE_VIEW: View = { yawDeg = 96, pitchDeg = 16 }
local SOLID_VIEW: View = { yawDeg = 34, pitchDeg = 25 }
local CARD_VIEW: View = { yawDeg = 15, pitchDeg = 9, pad = 1.18, rockDegrees = 17, rockSeconds = 9 }

-- HOW BIG THE ITEM IS AS THE CAMERA SEES IT: half its width and half its height on the camera's own
-- two axes. PURE, and it is the exact projection of an axis-aligned box onto a direction -- each
-- side's length times that side's share of the axis, halved.
--
-- THE FIRST FRAME OF THIS PANEL IS WHY IT EXISTS (rule 5, measured 2026-10-16 in
-- `.screenshots/196-shop-phone-a.png`). The framing was a bounding SPHERE, which is right for a hat
-- and wrong for a rifle: a 4.4-stud gun 0.9 studs tall has a 2.24-stud radius, so the camera stood
-- 10 studs back and drew the rifle a quarter of the way across its own picture with empty box above
-- and below it. A rod in a landscape frame has to be held by its WIDTH.
function ShopDisplay.halfExtents(size: Vector3, orientation: CFrame): (number, number)
	local right = orientation.RightVector
	local up = orientation.UpVector
	local halfWidth = 0.5 * (math.abs(size.X * right.X) + math.abs(size.Y * right.Y) + math.abs(size.Z * right.Z))
	local halfHeight = 0.5 * (math.abs(size.X * up.X) + math.abs(size.Y * up.Y) + math.abs(size.Z * up.Z))
	return halfWidth, halfHeight
end

-- HOW FAR BACK THE CAMERA HAS TO BE to hold a box this big in a lens of this angle on a frame of
-- this shape. PURE -- `tan` of the half-angle, the one piece of arithmetic in the framing -- so the
-- picture's framing is a spec and not a screenshot.
--
-- THE LENS'S ANGLE IS VERTICAL (Roblox's `Camera.FieldOfView` is), so the horizontal one is that
-- angle widened by the frame's aspect. Whichever of the two asks for more room wins: the rifle is
-- held by its width and the hat by its height, and neither is a special case.
function ShopDisplay.distanceFor(
	halfWidth: number,
	halfHeight: number,
	aspect: number?,
	fovDeg: number?,
	pad: number?
): number
	local fov = fovDeg or ShopDisplay.FOV_DEG
	local half = math.tan(math.rad(math.clamp(fov, 1, 120)) / 2)
	local shape = math.max(aspect or 1, 0.05)
	local air = pad or ShopDisplay.PAD
	local forHeight = (math.max(halfHeight, 0.01) * air) / half
	local forWidth = (math.max(halfWidth, 0.01) * air) / (half * shape)
	return math.max(forHeight, forWidth)
end

-- WHERE THE CAMERA IS AND WHAT IT LOOKS AT, for an item of this size at this moment. PURE.
--
-- THE CAMERA ORBITS AND THE MODEL STANDS STILL, which is the cheaper half of the same picture: one
-- `CFrame` written per frame instead of a `PivotTo` over every part, and no pivot to keep.
function ShopDisplay.cameraCFrame(
	centre: Vector3,
	size: Vector3,
	angleDeg: number,
	view: View?,
	aspect: number?
): CFrame
	local look = view or SOLID_VIEW
	local yaw = math.rad(look.yawDeg + angleDeg)
	local pitch = math.rad(look.pitchDeg)
	local direction = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch))
	-- THE ORIENTATION FIRST AND THE DISTANCE SECOND, because how big the item looks depends on which
	-- way the camera faces: one 4.4-stud gun is a rod end-on and a rod across the frame a quarter-turn
	-- later. One `CFrame` is built to ask that question, and its answer places the second.
	local orientation = CFrame.lookAt(centre + direction, centre)
	local halfWidth, halfHeight = ShopDisplay.halfExtents(size, orientation)
	local distance = ShopDisplay.distanceFor(halfWidth, halfHeight, aspect, ShopDisplay.FOV_DEG, look.pad)
	return CFrame.lookAt(centre + direction * distance, centre)
end

-- THE ANGLE AT THIS MOMENT, wrapped to one turn. PURE, and taken from a clock the caller passes, so
-- a spec drives the spin with a number (`Viewmodel.setClock`'s own arrangement).
--
-- A VIEW THAT ROCKS NEVER COMPLETES A TURN: `17 * sin(2*pi*t/9)` degrees either side of its own
-- yaw, which is the licence's whole motion (spec 6.4).
function ShopDisplay.spinDegAt(now: number, view: View?): number
	if view ~= nil and view.rockDegrees ~= nil and view.rockSeconds ~= nil then
		return (view.rockDegrees :: number) * math.sin((2 * math.pi * now) / (view.rockSeconds :: number))
	end
	return (now * ShopDisplay.SPIN_DEG_PER_S) % 360
end

-- ---------------------------------------------------------------- parts
--
-- EVERYTHING SAYS SCENERY, the same six properties `Weapon.Hardware` and `Camera.Viewmodel` put on
-- every part they draw. `CanQuery = false` is not decoration even here: these parts live under a
-- `ViewportFrame` in the PlayerGui, and a stray raycast must not find a shop window.
local function dress(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
end

-- ---------------------------------------------------------------- the rifles
--
-- WHICH MESHES HAVE ARRIVED ON THIS CLIENT. `Camera.Viewmodel.meshReady`'s question and its measured
-- reason, in the one form this module may have it: a `MeshPart` whose mesh has not been DOWNLOADED
-- renders as NOTHING, so wearing it means wearing a hole (task 133, measured at 390 ms with a warm
-- cache). The shop is worse than the viewmodel here, not better: a player who has only ever carried
-- the shotgun has never asked for the rifle's meshes at all, so the status starts at `None` and
-- stays there until somebody asks. This asks, once per id per session, and `ShopDisplay.rebuildWanted`
-- is what tells the panel to draw the thing again when they land.
local asked: { [string]: boolean } = {}
local arrived: { [string]: boolean } = {}
local waiting = 0

local function meshReady(part: Instance): boolean
	if not part:IsA("MeshPart") then
		return true
	end
	local id = (part :: MeshPart).MeshId
	if id == nil or id == "" then
		return false
	end
	if arrived[id] then
		return true
	end
	local ok, status = pcall(function()
		return ContentProvider:GetAssetFetchStatus(id)
	end)
	if not ok then
		return true -- a guard that cannot read the status must not withhold the real model for ever
	end
	if status == Enum.AssetFetchStatus.Success then
		arrived[id] = true
		return true
	end
	if not asked[id] then
		asked[id] = true
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync({ part })
			end)
		end)
	end
	return false
end

-- IS THE MODEL ON SCREEN WAITING FOR ANYTHING? The panel asks this after a build and draws the item
-- again when it goes back to zero, which is the same stale-and-rebuild path `Camera.Viewmodel` takes
-- when the server's folder appears late.
function ShopDisplay.rebuildWanted(): boolean
	return waiting > 0
end

-- ONE RIFLE, FROM THE ONE PIECE LIST. `config.SIGHT` is still what tells `Geometry.pieces` whether
-- the glass is on (task 143's filter) and the parameter stays, but since task 196 the catalogue has
-- ONE rifle in it: Karen removed the open-sighted row (*"remove rifle without scope soon don't
-- need"*), so nothing passes a sight and the scoped gun is what is drawn.
--
-- A PUBLISHED MESH WHERE IT HAS ARRIVED AND THE MEASURED BOX WHERE IT HAS NOT -- `Camera.Viewmodel`'s
-- own rule, so a shop window on a cold client is a plain dark rifle and never an empty rectangle.
-- All four meshes carry the WHOLE gun's bounding box, so ONE offset places every one of them
-- (`Rifle.Geometry`'s header), and that offset is the piece's own `meshOffset`: this file does not
-- compute a single coordinate of the gun.
-- ONE DRAWING FOR ANY GUN THIS REPO HAS GEOMETRY FOR (task 224). It was `buildRifle` and read
-- `RifleGeometry` directly; the lever rifle is the same drawing with a different module, because
-- every geometry in this game publishes the same function set precisely so a generic caller cannot
-- tell the guns apart (`Weapons.geometry(id)`'s own rule). A second copy of this loop would be a
-- second answer to "what does a gun look like in the shop window".
local function buildGun(parent: Model, geometry: any, config: any?)
	local folder = ReplicatedStorage:FindFirstChild(geometry.FOLDER_NAME)
	for _, piece in ipairs(geometry.pieces(config)) do
		local found = if folder and piece.meshKey ~= nil then folder:FindFirstChild(piece.name) else nil
		local mesh = if found and found:IsA("BasePart") then found :: BasePart else nil
		if mesh ~= nil and not meshReady(mesh) then
			mesh = nil
			waiting += 1
		end
		local part: BasePart
		local offset = piece.offset
		if mesh ~= nil then
			part = mesh:Clone()
			offset = piece.meshOffset or piece.offset
		else
			local made = Instance.new("Part")
			made.Size = piece.size
			made.Shape = piece.shape
			made.Color = piece.color
			made.Material = piece.material
			made.Reflectance = piece.reflectance or 0
			-- THE SCOPE'S FALLBACK IS A GHOST IN THE HAND, because it sits ON the sight line there.
			-- In a shop window there is no sight line and a ghost reads as a missing scope, so the
			-- window draws it solid: this is a photograph of the gun, not a thing to aim.
			made.Transparency = 0
			part = made
		end
		part.Name = piece.name
		dress(part)
		part.CFrame = offset
		part.Parent = parent
	end
end

local function buildRifle(parent: Model, sight: string?)
	local config = if sight ~= nil then { SIGHT = sight } else nil
	buildGun(parent, RifleGeometry, config)
end

-- THE LEVER RIFLE (task 224), from its own config so the window draws its own stainless and its own
-- grey laminate rather than the Rigby's blued steel and walnut.
local function buildLeverRifle(parent: Model)
	buildGun(parent, LeverGeometry, Lever.CONFIG)
end

-- ---------------------------------------------------------------- the three things that are not guns

-- THE DESIGNER'S OWN PART TABLES (the Designer's spec, 2026-10-16, section 6), typed out as they
-- are written there: shape, size in studs, position, rotation, colour, material. Karen asked for
-- *"nicer shells ect / license nicer"* and handed the look over; these three are the answer, and
-- every number below is quoted rather than chosen.
--
-- THE SHELF IS y = 0 AND +y IS UP, which is the spec's own frame, and the camera looks from +x/+z.
-- Nothing here reads the panel, the catalogue's prices or a player: a model is geometry.
--
-- NO TEXT ON ANY OF THEM, and that is the engine: a `SurfaceGui` does not render inside a
-- `ViewportFrame`. So every printed line on the box and on the licence is a BLOCK -- which is why
-- the label is three ink bars and the boar on the licence is twelve of them.

-- ONE ROW OF THE SPEC'S TABLES. `rot` is in DEGREES about the named axis, exactly as the tables
-- write it, so a reader can put this file and the spec side by side.
type Piece = {
	name: string,
	shape: Enum.PartType?,
	size: Vector3,
	at: Vector3,
	rot: Vector3?,
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
}

local function place(parent: Model, piece: Piece)
	local part = Instance.new("Part")
	part.Name = piece.name
	part.Shape = piece.shape or Enum.PartType.Block
	part.Size = piece.size
	local rot = piece.rot or Vector3.zero
	part.CFrame = CFrame.new(piece.at) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	part.Color = piece.color
	part.Material = piece.material or Enum.Material.SmoothPlastic
	part.Transparency = piece.transparency or 0
	dress(part)
	part.Parent = parent
	return part
end

local function pieces(parent: Model, rows: { Piece })
	for _, row in ipairs(rows) do
		place(parent, row)
	end
end

-- 6.1 SLUG SHELLS: a closed green paperboard box with a printed cream label, and three cartridges
-- standing in front of it, brass head down -- *"so the thing being sold is the thing you see"*.
-- The three stand clear of the label on purpose: the label stays readable while the model turns.
local SHELL_X = { -0.9, -0.52, -0.14 }

local function buildShellBox(parent: Model)
	pieces(parent, {
		{
			-- SMOOTHPLASTIC AND NOT THE SPEC'S `Fabric`, AND THE FIRST FRAME IS WHY (rule 5,
			-- `.screenshots/196-shop-desktop.png`): `Fabric`'s weave is sized in studs, so on a
			-- 1.8-stud box under the case's one light it read as grey SPECKLED STONE and the green
			-- the spec picked did not come through at all. Smooth plastic shows the colour, which is
			-- what the picture is for. The spec's own rule in section 9 covers this: *"the Part
			-- tables are the truth; the pictures are what they should come out looking like"*.
			name = "Box",
			size = Vector3.new(1.8, 0.86, 1),
			at = Vector3.new(0.18, 0.43, -0.55),
			color = Color3.fromHex("2B4733"),
		},
		{
			name = "Label",
			size = Vector3.new(1.5, 0.58, 0.02),
			at = Vector3.new(0.18, 0.49, -0.04),
			color = Color3.fromHex("EDE4CE"),
		},
		{
			-- -0.022 AND NOT THE SPEC'S -0.045, MEASURED (rule 5): the label is 0.02 thick centred at
			-- -0.04, so it spans -0.05 to -0.03 -- and every printed piece the spec puts at -0.045 is
			-- INSIDE it and invisible. The camera looks from +z, so the print has to stand in FRONT
			-- of the label's front face. Everything else about these four pieces is the spec's.
			name = "LabelBand",
			size = Vector3.new(1.5, 0.12, 0.022),
			at = Vector3.new(0.18, 0.72, -0.022),
			color = Color3.fromHex("D2661B"),
		},
		{
			name = "Print1",
			size = Vector3.new(0.84, 0.07, 0.022),
			at = Vector3.new(-0.08, 0.6, -0.022),
			color = Color3.fromHex("3A3630"),
		},
		{
			name = "Print2",
			size = Vector3.new(0.58, 0.05, 0.022),
			at = Vector3.new(-0.21, 0.49, -0.022),
			color = Color3.fromHex("7A7366"),
		},
		{
			name = "Print3",
			size = Vector3.new(0.37, 0.05, 0.022),
			at = Vector3.new(-0.33, 0.41, -0.022),
			color = Color3.fromHex("7A7366"),
		},
		{
			name = "Seal",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.03, 0.32, 0.32),
			at = Vector3.new(0.7, 0.55, -0.02),
			rot = Vector3.new(0, 90, 0),
			color = Color3.fromHex("C8A258"),
			material = Enum.Material.Metal,
		},
		{
			name = "SealRing",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.034, 0.22, 0.22),
			at = Vector3.new(0.7, 0.55, -0.026),
			rot = Vector3.new(0, 90, 0),
			color = Color3.fromHex("8E6F30"),
			material = Enum.Material.Metal,
		},
	})
	for index, x in ipairs(SHELL_X) do
		pieces(parent, {
			{
				name = string.format("Hull%d", index),
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(0.66, 0.235, 0.235),
				at = Vector3.new(x, 0.59, 0.98),
				rot = Vector3.new(0, 0, 90),
				color = Color3.fromHex("B3281F"),
			},
			{
				name = string.format("Crimp%d", index),
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(0.05, 0.215, 0.215),
				at = Vector3.new(x, 0.895, 0.98),
				rot = Vector3.new(0, 0, 90),
				color = Color3.fromHex("8E1F18"),
			},
			{
				name = string.format("Brass%d", index),
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(0.26, 0.25, 0.25),
				at = Vector3.new(x, 0.13, 0.98),
				rot = Vector3.new(0, 0, 90),
				color = Color3.fromHex("C8A258"),
				material = Enum.Material.Metal,
			},
			{
				name = string.format("Rim%d", index),
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(0.05, 0.275, 0.275),
				at = Vector3.new(x, 0.025, 0.98),
				rot = Vector3.new(0, 0, 90),
				color = Color3.fromHex("A8853F"),
				material = Enum.Material.Metal,
			},
		})
	end
end

-- 6.2 THE BEATER LICENCE: a real document standing upright -- green header with a cream boar mark
-- and a brass eyelet, a photograph, three rows of print, a brass crest and a red rubber stamp. The
-- back of the card is green. Front face at z = +0.026; the print sits at 0.026-0.032.
local INK = Color3.fromHex("2C2A26")
local FIELD = Color3.fromHex("9A9384")
local CREAM = Color3.fromHex("EDE4CE")
local LODEN = Color3.fromHex("27452E")
local BRASS = Color3.fromHex("C8A258")
local STAMP = Color3.fromHex("9B3A32")
-- TASK 221's THREE: the weathered timber a high seat is built of (`HighSeats.COLORS`' own two, which
-- were chosen against the lodge's logs and looked at in the live place), and the hunters' orange,
-- which is `Style.LOOK.BLAZE` -- named here rather than required, because this module draws PARTS
-- and has never required the Hud's palette.
local TIMBER = Color3.fromHex("8A7A5E")
local TIMBER_DARK = Color3.fromHex("6B5E47")
local BLAZE = Color3.fromHex("E2641B")

-- THE BOAR MARK, 12 blocks in the header bar -- all cream, all 0.02 thick, all at z = 0.028. The
-- spec names which five make it a boar if the count ever has to come down: rump, body, back, head,
-- snout.
local BOAR_MARK: { { name: string, size: Vector2, at: Vector2, rot: number? } } = {
	{ name = "MarkRump", size = Vector2.new(0.082, 0.091), at = Vector2.new(-0.773, 1.075) },
	{ name = "MarkBody", size = Vector2.new(0.191, 0.082), at = Vector2.new(-0.691, 1.07) },
	{ name = "MarkBack", size = Vector2.new(0.136, 0.045), at = Vector2.new(-0.709, 1.115), rot = 7 },
	{ name = "MarkHead", size = Vector2.new(0.091, 0.082), at = Vector2.new(-0.577, 1.079), rot = 12 },
	{ name = "MarkSnout", size = Vector2.new(0.055, 0.036), at = Vector2.new(-0.532, 1.065) },
	{ name = "MarkEar", size = Vector2.new(0.036, 0.036), at = Vector2.new(-0.595, 1.129), rot = -18 },
	{ name = "MarkTusk", size = Vector2.new(0.036, 0.018), at = Vector2.new(-0.514, 1.065), rot = 38 },
	{ name = "MarkTail", size = Vector2.new(0.036, 0.018), at = Vector2.new(-0.814, 1.12), rot = -32 },
	{ name = "MarkLeg1", size = Vector2.new(0.023, 0.055), at = Vector2.new(-0.757, 1.011) },
	{ name = "MarkLeg2", size = Vector2.new(0.023, 0.055), at = Vector2.new(-0.721, 1.011) },
	{ name = "MarkLeg3", size = Vector2.new(0.023, 0.055), at = Vector2.new(-0.657, 1.011) },
	{ name = "MarkLeg4", size = Vector2.new(0.023, 0.055), at = Vector2.new(-0.621, 1.011) },
}

local function buildLicence(parent: Model)
	pieces(parent, {
		{
			name = "Card",
			size = Vector3.new(1.9, 1.22, 0.05),
			at = Vector3.new(0, 0.61, 0),
			color = CREAM,
		},
		{
			name = "Back",
			size = Vector3.new(1.9, 1.22, 0.012),
			at = Vector3.new(0, 0.61, -0.031),
			color = LODEN,
			material = Enum.Material.Fabric,
		},
		{ name = "Header", size = Vector3.new(1.9, 0.27, 0.02), at = Vector3.new(0, 1.085, 0.026), color = LODEN },
		{
			name = "HeaderRule",
			size = Vector3.new(1.9, 0.018, 0.022),
			at = Vector3.new(0, 0.938, 0.027),
			color = BRASS,
			material = Enum.Material.Metal,
		},
		{
			name = "Title1",
			size = Vector3.new(0.76, 0.064, 0.022),
			at = Vector3.new(-0.04, 1.106, 0.028),
			color = Color3.fromHex("EFE6D2"),
		},
		{
			name = "Title2",
			size = Vector3.new(0.47, 0.036, 0.022),
			at = Vector3.new(-0.19, 1.029, 0.028),
			color = Color3.fromHex("BFCBB8"),
		},
		{
			name = "Eyelet",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.06, 0.11, 0.11),
			at = Vector3.new(0.8, 1.084, 0.026),
			rot = Vector3.new(0, 90, 0),
			color = BRASS,
			material = Enum.Material.Metal,
		},
		{
			name = "EyeletHole",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.07, 0.05, 0.05),
			at = Vector3.new(0.8, 1.084, 0.028),
			rot = Vector3.new(0, 90, 0),
			color = Color3.fromHex("2A2419"),
		},
		{
			name = "Photo",
			size = Vector3.new(0.42, 0.51, 0.02),
			at = Vector3.new(-0.63, 0.584, 0.026),
			color = Color3.fromHex("6E7A66"),
		},
		{
			name = "PhotoHead",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.03, 0.15, 0.15),
			at = Vector3.new(-0.63, 0.688, 0.028),
			rot = Vector3.new(0, 90, 0),
			color = Color3.fromHex("2F3A2C"),
		},
		{
			name = "PhotoBody",
			size = Vector3.new(0.25, 0.2, 0.025),
			at = Vector3.new(-0.63, 0.502, 0.028),
			color = Color3.fromHex("2F3A2C"),
		},
		{
			name = "Sig1",
			size = Vector3.new(0.4, 0.027, 0.022),
			at = Vector3.new(-0.64, 0.261, 0.028),
			rot = Vector3.new(0, 0, 2),
			color = Color3.fromHex("2A3E6B"),
		},
		{
			name = "Sig2",
			size = Vector3.new(0.27, 0.027, 0.022),
			at = Vector3.new(-0.67, 0.215, 0.028),
			rot = Vector3.new(0, 0, -2),
			color = Color3.fromHex("2A3E6B"),
		},
		{
			name = "Field1Label",
			size = Vector3.new(0.25, 0.036, 0.022),
			at = Vector3.new(-0.19, 0.802, 0.028),
			color = FIELD,
		},
		{
			name = "Field1Value",
			size = Vector3.new(0.85, 0.082, 0.022),
			at = Vector3.new(0.11, 0.706, 0.028),
			color = INK,
		},
		{
			name = "Field2Label",
			size = Vector3.new(0.22, 0.036, 0.022),
			at = Vector3.new(-0.21, 0.566, 0.028),
			color = FIELD,
		},
		{
			name = "Field2Value",
			size = Vector3.new(0.6, 0.064, 0.022),
			at = Vector3.new(-0.01, 0.479, 0.028),
			color = INK,
		},
		{
			name = "Field3Label",
			size = Vector3.new(0.27, 0.036, 0.022),
			at = Vector3.new(-0.18, 0.347, 0.028),
			color = FIELD,
		},
		{
			name = "Field3Value",
			size = Vector3.new(0.45, 0.064, 0.022),
			at = Vector3.new(-0.09, 0.261, 0.028),
			color = INK,
		},
		{
			name = "CrestTop",
			size = Vector3.new(0.29, 0.16, 0.022),
			at = Vector3.new(0.705, 0.72, 0.028),
			color = BRASS,
			material = Enum.Material.Metal,
		},
		{
			name = "CrestPoint",
			size = Vector3.new(0.21, 0.21, 0.022),
			at = Vector3.new(0.705, 0.643, 0.028),
			rot = Vector3.new(0, 0, 45),
			color = Color3.fromHex("A8853F"),
			material = Enum.Material.Metal,
		},
		{
			name = "CrestFieldTop",
			size = Vector3.new(0.24, 0.13, 0.024),
			at = Vector3.new(0.705, 0.711, 0.03),
			color = LODEN,
		},
		{
			name = "CrestFieldPt",
			size = Vector3.new(0.16, 0.16, 0.024),
			at = Vector3.new(0.705, 0.656, 0.03),
			rot = Vector3.new(0, 0, 45),
			color = LODEN,
		},
		{
			name = "CrestBar1",
			size = Vector3.new(0.15, 0.027, 0.026),
			at = Vector3.new(0.705, 0.716, 0.032),
			color = Color3.fromHex("D8B36A"),
			material = Enum.Material.Metal,
		},
		{
			name = "CrestBar2",
			size = Vector3.new(0.11, 0.027, 0.026),
			at = Vector3.new(0.705, 0.67, 0.032),
			color = Color3.fromHex("D8B36A"),
			material = Enum.Material.Metal,
		},
		{
			name = "StampRing",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.012, 0.47, 0.47),
			at = Vector3.new(0.45, 0.293, 0.028),
			rot = Vector3.new(0, 90, 0),
			color = STAMP,
			transparency = 0.25,
		},
		{
			name = "StampHole",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.012, 0.415, 0.415),
			at = Vector3.new(0.45, 0.293, 0.03),
			rot = Vector3.new(0, 90, 0),
			color = CREAM,
		},
		{
			name = "StampRing2",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.012, 0.3, 0.3),
			at = Vector3.new(0.45, 0.293, 0.031),
			rot = Vector3.new(0, 90, 0),
			color = STAMP,
			transparency = 0.4,
		},
		{
			name = "StampHole2",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.012, 0.275, 0.275),
			at = Vector3.new(0.45, 0.293, 0.032),
			rot = Vector3.new(0, 90, 0),
			color = CREAM,
		},
		{
			name = "StampBar",
			size = Vector3.new(0.47, 0.055, 0.03),
			at = Vector3.new(0.45, 0.293, 0.033),
			rot = Vector3.new(0, 0, 13),
			color = STAMP,
			transparency = 0.25,
		},
	})
	for _, mark in ipairs(BOAR_MARK) do
		place(parent, {
			name = mark.name,
			size = Vector3.new(mark.size.X, mark.size.Y, 0.02),
			at = Vector3.new(mark.at.X, mark.at.Y, 0.028),
			rot = if mark.rot ~= nil then Vector3.new(0, 0, mark.rot) else nil,
			color = Color3.fromHex("EFE6D2"),
		})
	end
end

-- 6.3 THE RED HAT. The crown colour is the ROW'S OWN `grants.hatColor` and is read, never
-- hard-coded -- *"because the colour is the thing being sold"*. The band is that colour at 55 %
-- brightness and the peak at 82 %.
local function shade(color: Color3, fraction: number): Color3
	return Color3.new(color.R * fraction, color.G * fraction, color.B * fraction)
end

local function buildHat(parent: Model, id: string)
	local row = (ShopData.ROWS :: any)[id]
	local crown = (row and row.grants and row.grants.hatColor) or Color3.fromHex("962620")
	local band = shade(crown, 0.55)
	local peak = shade(crown, 0.82)
	pieces(parent, {
		{
			-- A NON-UNIFORM BALL. The spec's own fallback is written down beside it: if a stretched
			-- `Ball` does not come out on the live build, make it 1.06 cubed and sink it 0.16 into
			-- the band. Checked on the live build and it stretches.
			name = "Crown",
			shape = Enum.PartType.Ball,
			size = Vector3.new(1.12, 0.74, 1.06),
			at = Vector3.new(0, 0.37, 0),
			color = crown,
			material = Enum.Material.Fabric,
		},
		{
			name = "Band",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.12, 1.14, 1.14),
			at = Vector3.new(0, 0.06, 0),
			rot = Vector3.new(0, 0, 90),
			color = Color3.fromHex("2C2A26"),
			material = Enum.Material.Fabric,
		},
		{
			name = "Peak",
			size = Vector3.new(1.02, 0.07, 0.62),
			at = Vector3.new(0, 0.1, 0.52),
			rot = Vector3.new(-8, 0, 0),
			color = peak,
			material = Enum.Material.Fabric,
		},
		{
			name = "PeakTip",
			size = Vector3.new(0.92, 0.06, 0.24),
			at = Vector3.new(0, 0.04, 0.92),
			rot = Vector3.new(-20, 0, 0),
			color = peak,
			material = Enum.Material.Fabric,
		},
		{
			name = "Button",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.05, 0.14, 0.14),
			at = Vector3.new(0, 0.74, 0),
			rot = Vector3.new(0, 0, 90),
			color = peak,
			material = Enum.Material.Fabric,
		},
	})
	for index, turn in ipairs({ 0, 60, 120 }) do
		place(parent, {
			name = string.format("Seam%d", index),
			size = Vector3.new(0.02, 0.5, 1.06),
			at = Vector3.new(0, 0.4, 0),
			rot = Vector3.new(0, turn, 0),
			color = shade(band, 0.8),
			material = Enum.Material.Fabric,
		})
	end
	for index, side in ipairs({ -1, 1 }) do
		place(parent, {
			name = string.format("Eyelet%d", index),
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.03, 0.07, 0.07),
			at = Vector3.new(side * 0.4, 0.46, 0.18),
			rot = Vector3.new(0, 90, 0),
			color = BRASS,
			material = Enum.Material.Metal,
		})
	end
end

-- ---------------------------------------------------------------- the v1 catalogue's own pictures
-- (task 221 round 3)
--
-- THE DIRECTOR, 2026-10-20: *"every row the shop sells gets a display model in ShopDisplay.DRAW …
-- built from parts like the existing ones; no uploads"*. Six rows arrived with Karen's v1 list and
-- `DRAW` knew four ids, so six of ten showed an empty case -- which is a declared fallback and
-- still the wrong thing for a shop window.
--
-- EVERY ONE IS PARTS, in the palette this file already has, at the scale the existing four use
-- (about 1.2 to 2 studs, which is what `distanceFor` was tuned against).

-- THE HIGH SEAT, IN MINIATURE: four legs, a deck, a rail on the far three faces and a truss
-- ladder -- the same silhouette `HighSeats.plan` builds at full size, at about a tenth of it. The
-- rail is left OFF the front face on purpose: it is the face the camera is on, and a bar across it
-- would hide the deck that is the thing being sold.
local SEAT_LEG = { { -0.42, -0.42 }, { 0.42, -0.42 }, { -0.42, 0.42 }, { 0.42, 0.42 } }

local function buildHighSeat(parent: Model)
	local rows: { Piece } = {}
	for index, leg in ipairs(SEAT_LEG) do
		table.insert(rows, {
			name = string.format("Leg%d", index),
			size = Vector3.new(0.1, 1.18, 0.1),
			at = Vector3.new(leg[1], 0.59, leg[2]),
			color = TIMBER,
			material = Enum.Material.Wood,
		})
	end
	table.insert(rows, {
		name = "Deck",
		size = Vector3.new(1.02, 0.08, 1.02),
		at = Vector3.new(0, 1.22, 0),
		color = TIMBER,
		material = Enum.Material.Wood,
	})
	-- THE BOARD A MAN RESTS A GUN ON, on three faces. `HighSeats.DIMS` puts the real one at 0.67 m
	-- above the deck; at this scale that is 0.3.
	local rail = {
		{ name = "RailBack", size = Vector3.new(1.02, 0.09, 0.07), at = Vector3.new(0, 1.52, 0.48) },
		{ name = "RailLeft", size = Vector3.new(0.07, 0.09, 1.02), at = Vector3.new(-0.48, 1.52, 0) },
		{ name = "RailRight", size = Vector3.new(0.07, 0.09, 1.02), at = Vector3.new(0.48, 1.52, 0) },
	}
	for _, board in ipairs(rail) do
		table.insert(rows, {
			name = board.name,
			size = board.size,
			at = board.at,
			color = TIMBER_DARK,
			material = Enum.Material.Wood,
		})
	end
	for _, post in ipairs({ -0.48, 0.48 }) do
		table.insert(rows, {
			name = string.format("Upright%d", if post < 0 then 1 else 2),
			size = Vector3.new(0.07, 0.34, 0.07),
			at = Vector3.new(post, 1.39, 0.48),
			color = TIMBER_DARK,
			material = Enum.Material.Wood,
		})
	end
	-- THE LADDER, as two rails and four rungs. The real one is a `TrussPart` and the climb is the
	-- engine's own `Climbing` state; a picture of it is three sticks.
	for _, side in ipairs({ -0.16, 0.16 }) do
		table.insert(rows, {
			name = string.format("LadderRail%d", if side < 0 then 1 else 2),
			size = Vector3.new(0.06, 1.26, 0.06),
			at = Vector3.new(side, 0.63, -0.62),
			color = TIMBER_DARK,
			material = Enum.Material.Wood,
		})
	end
	for rung = 1, 4 do
		table.insert(rows, {
			name = string.format("Rung%d", rung),
			size = Vector3.new(0.38, 0.045, 0.045),
			at = Vector3.new(0, 0.22 * rung, -0.62),
			color = TIMBER_DARK,
			material = Enum.Material.Wood,
		})
	end
	pieces(parent, rows)
end

-- UNLIMITED AMMUNITION: an open crate with shells standing in it, stencilled. It is the SLUG box's
-- own vocabulary at a bigger size, which is the point -- what is being sold is not a different
-- shell, it is never running out of them.
local CRATE_SHELL = { -0.3, -0.1, 0.1, 0.3 }

local function buildAmmoCrate(parent: Model)
	local rows: { Piece } = {
		{
			name = "Floor",
			size = Vector3.new(1.3, 0.07, 0.86),
			at = Vector3.new(0, 0.035, 0),
			color = TIMBER,
			material = Enum.Material.Wood,
		},
		{
			name = "Front",
			size = Vector3.new(1.3, 0.56, 0.07),
			at = Vector3.new(0, 0.28, -0.4),
			color = TIMBER,
			material = Enum.Material.Wood,
		},
		{
			name = "Back",
			size = Vector3.new(1.3, 0.56, 0.07),
			at = Vector3.new(0, 0.28, 0.4),
			color = TIMBER,
			material = Enum.Material.Wood,
		},
		{
			name = "Left",
			size = Vector3.new(0.07, 0.56, 0.86),
			at = Vector3.new(-0.62, 0.28, 0),
			color = TIMBER_DARK,
			material = Enum.Material.Wood,
		},
		{
			name = "Right",
			size = Vector3.new(0.07, 0.56, 0.86),
			at = Vector3.new(0.62, 0.28, 0),
			color = TIMBER_DARK,
			material = Enum.Material.Wood,
		},
		-- THE STENCIL, as two bars: this file draws no text, and the licence card already says a
		-- printed line with a Part.
		{
			name = "Stencil1",
			size = Vector3.new(0.52, 0.07, 0.016),
			at = Vector3.new(-0.18, 0.37, -0.44),
			color = CREAM,
		},
		{
			name = "Stencil2",
			size = Vector3.new(0.33, 0.05, 0.016),
			at = Vector3.new(-0.27, 0.25, -0.44),
			color = CREAM,
		},
	}
	-- FOUR SHELLS STANDING, brass down, above the crate's rim so the thing being sold is the thing
	-- you see -- the slug box's own stated rule.
	for index, x in ipairs(CRATE_SHELL) do
		table.insert(rows, {
			name = string.format("Shell%d", index),
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.46, 0.17, 0.17),
			at = Vector3.new(x, 0.52, 0.06),
			rot = Vector3.new(0, 0, 90),
			color = STAMP,
		})
		table.insert(rows, {
			name = string.format("Head%d", index),
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.12, 0.18, 0.18),
			at = Vector3.new(x, 0.35, 0.06),
			rot = Vector3.new(0, 0, 90),
			color = BRASS,
			material = Enum.Material.Metal,
		})
	end
	pieces(parent, rows)
end

-- THE RED STAG CARD: the beater licence's own card with a STAG on it instead of a plain panel --
-- head, neck and a pair of antlers, in silhouette. It is the same card on purpose: a licence is a
-- licence, and what tells them apart is the animal.
local function buildStagCard(parent: Model)
	buildLicence(parent)
	local antler = { -0.22, 0.22 }
	local rows: { Piece } = {
		-- The panel the silhouette sits on, so the stag reads against the cream rather than on it.
		{ name = "Panel", size = Vector3.new(1.18, 0.6, 0.016), at = Vector3.new(0, 0.52, 0.027), color = LODEN },
		{
			name = "StagBody",
			size = Vector3.new(0.5, 0.26, 0.018),
			at = Vector3.new(-0.06, 0.44, 0.036),
			color = CREAM,
		},
		{
			name = "StagNeck",
			size = Vector3.new(0.13, 0.26, 0.018),
			at = Vector3.new(0.17, 0.58, 0.036),
			color = CREAM,
		},
		{ name = "StagHead", size = Vector3.new(0.23, 0.1, 0.018), at = Vector3.new(0.25, 0.69, 0.036), color = CREAM },
		{ name = "LegF", size = Vector3.new(0.055, 0.2, 0.018), at = Vector3.new(0.06, 0.24, 0.036), color = CREAM },
		{ name = "LegB", size = Vector3.new(0.055, 0.2, 0.018), at = Vector3.new(-0.24, 0.24, 0.036), color = CREAM },
	}
	for index, dx in ipairs(antler) do
		table.insert(rows, {
			name = string.format("Antler%d", index),
			size = Vector3.new(0.035, 0.21, 0.018),
			at = Vector3.new(0.21 + dx * 0.16, 0.83, 0.036),
			rot = Vector3.new(0, 0, dx * 26),
			color = CREAM,
		})
		for tine = 1, 2 do
			table.insert(rows, {
				name = string.format("Tine%d%d", index, tine),
				size = Vector3.new(0.03, 0.1, 0.018),
				at = Vector3.new(0.21 + dx * (0.2 + tine * 0.03), 0.8 + tine * 0.06, 0.036),
				rot = Vector3.new(0, 0, dx * 52),
				color = CREAM,
			})
		end
	end
	pieces(parent, rows)
end

-- ALWAYS HUNTER: a hunter's badge -- a brass shield on a loden backing, with the orange band the
-- hunters already wear across it. Not a card: what is sold is a STANDING, and a badge is what a
-- standing looks like.
local function buildBadge(parent: Model)
	pieces(parent, {
		{
			name = "Shield",
			size = Vector3.new(1.08, 1.24, 0.07),
			at = Vector3.new(0, 0.62, 0),
			color = BRASS,
			material = Enum.Material.Metal,
		},
		{
			name = "Point",
			size = Vector3.new(0.76, 0.76, 0.07),
			at = Vector3.new(0, 0.1, 0),
			rot = Vector3.new(0, 0, 45),
			color = BRASS,
			material = Enum.Material.Metal,
		},
		{
			name = "Face",
			size = Vector3.new(0.86, 1.0, 0.03),
			at = Vector3.new(0, 0.66, 0.042),
			color = LODEN,
			material = Enum.Material.Fabric,
		},
		-- THE HUNTERS' OWN ORANGE, so the badge belongs to the side it buys you a place on.
		{ name = "Band", size = Vector3.new(0.86, 0.2, 0.034), at = Vector3.new(0, 0.5, 0.046), color = BLAZE },
		{
			name = "Pin",
			size = Vector3.new(0.3, 0.05, 0.05),
			at = Vector3.new(0, 1.3, 0),
			color = BRASS,
			material = Enum.Material.Metal,
		},
	})
end

-- A PACKAGE: its contents, side by side on a shelf board. Nothing new is drawn -- each part is the
-- model that row already has, scaled down and set along the board -- so a package can never show
-- something it does not contain, and a row that gains a picture gains it inside every package that
-- covers it. `ShopDisplay.knows` is what decides which contents are drawable.
local BUNDLE_SPREAD = 1.45

local function buildBundle(parent: Model, id: string)
	local row = ShopData.anyRow(id)
	local covers = (row and row.covers) or {}
	local drawable: { string } = {}
	for _, covered in ipairs(covers) do
		if ShopDisplay.knows(covered) then
			table.insert(drawable, covered)
		end
	end
	pieces(parent, {
		{
			name = "Board",
			size = Vector3.new(math.max(1.2, #drawable * BUNDLE_SPREAD + 0.4), 0.08, 1.1),
			at = Vector3.new(0, 0.04, 0),
			color = TIMBER_DARK,
			material = Enum.Material.Wood,
		},
	})
	local span = (#drawable - 1) * BUNDLE_SPREAD
	for index, covered in ipairs(drawable) do
		-- THROUGH `ShopDisplay.build`, so a package draws EXACTLY the model that row draws on its
		-- own page: there is one drawing per item and a package cannot show something it does not
		-- contain. It cannot recurse -- `rowsOk` I7 refuses a package that covers a package.
		local piece = ShopDisplay.build(covered)
		if piece ~= nil then
			piece.Name = string.format("Part%d", index)
			-- SCALED AND SET ALONG THE BOARD. `GetBoundingBox` is the same answer this file's own
			-- framing is measured with, so there is no table of offsets to go stale the day a
			-- model changes.
			local _, size = piece:GetBoundingBox()
			local tallest = math.max(size.X, size.Y, size.Z)
			local scale = if tallest > 0 then math.clamp(1.15 / tallest, 0.05, 1) else 1
			piece:ScaleTo(scale)
			local at = Vector3.new(-span / 2 + (index - 1) * BUNDLE_SPREAD, 0.08 + (size.Y * scale) / 2, 0)
			piece:PivotTo(CFrame.new(at))
			piece.Parent = parent
		end
	end
end

-- ---------------------------------------------------------------- what to draw for an id

-- THE ONE TABLE THAT SAYS WHICH DRAWING AND WHICH CAMERA EACH ITEM GETS, keyed by the catalogue's own
-- ids. An id this table does not name draws NOTHING and the panel says so in words
-- (`Shop.CONFIG.TEXT.PICK`) rather than showing an empty rectangle -- the refusal `HeldTool.kindOf`
-- already makes for a Tool it does not name, and for the same reason: *"draw whatever is in the
-- hand"* is what once drew a shotgun out of a horn.
local DRAW: { [string]: { view: View, build: (Model, string) -> () } } = {
	[ShopData.ITEM.LEVER] = {
		view = RIFLE_VIEW,
		build = function(model: Model, _id: string)
			buildLeverRifle(model)
		end,
	},
	[ShopData.ITEM.RIFLE] = {
		view = RIFLE_VIEW,
		build = function(model: Model, _id: string)
			buildRifle(model, nil) -- nil SIGHT is the scoped rifle: `Geometry.sightKind`'s default
		end,
	},
	[ShopData.ITEM.SLUG] = {
		view = SOLID_VIEW,
		build = function(model: Model, _id: string)
			buildShellBox(model)
		end,
	},
	[ShopData.ITEM.HAT_RED] = {
		view = SOLID_VIEW,
		build = function(model: Model, id: string)
			buildHat(model, id)
		end,
	},
	[ShopData.ITEM.BEATER_LICENCE] = {
		view = CARD_VIEW,
		build = function(model: Model, _id: string)
			buildLicence(model)
		end,
	},
	-- TASK 221: EVERY ROW THE SHOP SELLS HAS A PICTURE NOW (the Director, 2026-10-20). Six of the
	-- ten were drawing nothing, which is a declared fallback and still the wrong thing for a shop.
	[ShopData.ITEM.HIGH_SEAT] = {
		view = SOLID_VIEW,
		build = function(model: Model, _id: string)
			buildHighSeat(model)
		end,
	},
	[ShopData.ITEM.UNLIMITED_AMMO] = {
		view = SOLID_VIEW,
		build = function(model: Model, _id: string)
			buildAmmoCrate(model)
		end,
	},
	[ShopData.ITEM.RED_STAG] = {
		view = CARD_VIEW,
		build = function(model: Model, _id: string)
			buildStagCard(model)
		end,
	},
	[ShopData.ITEM.ALWAYS_HUNTER] = {
		view = CARD_VIEW,
		build = function(model: Model, _id: string)
			buildBadge(model)
		end,
	},
	-- THE PACKAGES DRAW THEIR OWN CONTENTS, through `ShopDisplay.build` per covered row -- so there
	-- is one drawing per item, a package can never show something it does not contain, and a row
	-- that gains a picture gains it inside every package that covers it.
	[ShopData.ITEM.BUNDLE_HIDE] = {
		view = SOLID_VIEW,
		build = buildBundle,
	},
	[ShopData.ITEM.BUNDLE_MARKSMAN] = {
		view = SOLID_VIEW,
		build = buildBundle,
	},
	[ShopData.ITEM.BUNDLE_SEASON] = {
		view = SOLID_VIEW,
		build = buildBundle,
	},
}

function ShopDisplay.knows(id: string?): boolean
	return id ~= nil and DRAW[id] ~= nil
end

function ShopDisplay.viewFor(id: string?): View
	local entry = if id ~= nil then DRAW[id] else nil
	return if entry then entry.view else SOLID_VIEW
end

-- THE MODEL FOR ONE ITEM, parentless, at the origin. nil for an id this module does not draw.
function ShopDisplay.build(id: string?): Model?
	local entry = if id ~= nil then DRAW[id] else nil
	if entry == nil then
		return nil
	end
	waiting = 0
	local model = Instance.new("Model")
	model.Name = string.format("ShopItem_%s", id :: string)
	entry.build(model, id :: string)
	local first = model:FindFirstChildWhichIsA("BasePart")
	if first == nil then
		model:Destroy()
		return nil
	end
	model.PrimaryPart = first
	return model
end

-- THE BOX THE CAMERA HAS TO HOLD: where the item is and how big it is. Read off the model rather
-- than declared per item, so a piece added to a drawing cannot push itself out of frame.
function ShopDisplay.frameOf(model: Model?): (Vector3, Vector3)
	if model == nil then
		return Vector3.zero, Vector3.one
	end
	local size = model:GetExtentsSize()
	local ok, box = pcall(function()
		return (model :: Model):GetBoundingBox()
	end)
	local centre = if ok and box then (box :: CFrame).Position else Vector3.zero
	return centre, size
end

return ShopDisplay
