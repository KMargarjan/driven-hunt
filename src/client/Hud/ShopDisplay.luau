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
local SemiAuto = require(ReplicatedStorage:WaitForChild("SemiAuto"))
local LeverGeometry = require(ReplicatedStorage:WaitForChild("Lever"):WaitForChild("Geometry"))
local SemiAutoGeometry = require(ReplicatedStorage:WaitForChild("SemiAuto"):WaitForChild("Geometry"))
local RifleGeometry = require(ReplicatedStorage:WaitForChild("Rifle"):WaitForChild("Geometry"))
-- THE REAL HIGH SEAT'S OWN NUMBERS AND COLOURS (task 228). `HighSeats` is the module
-- `ForestTest.Seats` builds the stands on the drive line out of, and the miniature in the shop
-- window is that module's `DIMS` times one scale -- so there is no second measurement of the seat.
local HighSeats = require(ReplicatedStorage:WaitForChild("HighSeats"))
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
-- TASK 228 (shop2 spec 2.3). `BOOK_VIEW` is for the two licences: a shade more pitch than
-- `CARD_VIEW` so you LOOK DOWN INTO an open booklet, and a slower, shorter rock so the print never
-- smears. `TALL_VIEW` is for the high seat -- the thing is 2.3 studs tall and about 1 wide, and
-- `SOLID_VIEW`'s 25 degrees of pitch would squash it into a deck seen from above, which is exactly
-- what `.screenshots/228-before-access-highseat.png` shows.
local BOOK_VIEW: View = { yawDeg = 13, pitchDeg = 14, pad = 1.14, rockDegrees = 15, rockSeconds = 10 }
local TALL_VIEW: View = { yawDeg = 30, pitchDeg = 11, pad = 1.12 }

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

-- THE SEMI-AUTOMATIC SHOTGUN (task 225), from its own config so the window draws its own blued
-- steel and walnut -- and its own RED DOT, which `Geometry.pieces` carries as an ordinary piece, so
-- the window gets it for free and `buildGun` needed no edit. `buildGun` is already "one drawing for
-- any gun this repo has geometry for" (task 224), which is why this is three lines.
local function buildSemiAuto(parent: Model)
	buildGun(parent, SemiAutoGeometry, SemiAuto.CONFIG)
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
	-- TASK 228 (shop2 spec 2.1): three lines, and *"it is the difference between enamel and
	-- plastic"*. Enamel, glass and brass want it; everything else leaves it at 0.
	reflectance: number?,
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
	part.Reflectance = piece.reflectance or 0
	dress(part)
	part.Parent = parent
	return part
end

local function pieces(parent: Model, rows: { Piece })
	for _, row in ipairs(rows) do
		place(parent, row)
	end
end

-- ---------------------------------------------------------------- the palette
--
-- EVERY ITEM IN THIS SHOP IS WOOD, BRASS, CARD OR CLOTH, and these are the hexes it is made of.
-- The first nine are task 196's and task 221's; everything from `BURGUNDY` down is the shop2 spec's
-- section 2.2 (the Designer, 2026-10-21, `<runs-dir>/design/shop2-spec.md`).
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

-- TASK 228: the shop2 spec's section 2.2.
local BURGUNDY = Color3.fromHex("6E1F22") -- the deer licence's cover cloth
local OXBLOOD = Color3.fromHex("4A1416") -- its inset panel and its shadowed edge
local LODEN_DARK = Color3.fromHex("1B3220") -- the beater licence's and the pin card's inset
local PAPER_WARM = Color3.fromHex("F3EBD6") -- a licence's inner page
local PAPER_TINT = Color3.fromHex("E3D9BE") -- the security tint a motif sits on
local GUILLOCHE = Color3.fromHex("C9B98E") -- the fine ruled lines over that tint
local STAG_HIDE = Color3.fromHex("7A4A26") -- the red stag, in silhouette
local STAG_DARK = Color3.fromHex("5B3418") -- its antlers and legs
local HORN_BRASS = Color3.fromHex("B8903F") -- the beater's horn
local HORN_HI = Color3.fromHex("E0BE72")
local VEST_ORANGE = Color3.fromHex("E8621A") -- beater orange: hotter than BLAZE on purpose
local VEST_DEEP = Color3.fromHex("B9440C")
local LEATHER = Color3.fromHex("6B4A2C") -- the bandolier's strap
local LEATHER_DK = Color3.fromHex("4C341E")
local LEATHER_HI = Color3.fromHex("8A6038")
local HULL_RED = Color3.fromHex("A8352C") -- a slug hull
local HULL_CRIMP = Color3.fromHex("8C2A22")
local HEAD_BRASS = Color3.fromHex("B9892F") -- a cartridge head
local STEEL = Color3.fromHex("7E8488")
local STEEL_DK = Color3.fromHex("4A4F52")
local ENAMEL = Color3.fromHex("1E4A2A") -- the pin's green
local WAX = Color3.fromHex("8E2118") -- a stamp's ink
local CASE_GREEN = Color3.fromHex("1E3524") -- a carton's shadowed wall

-- ---------------------------------------------------------------- 2.4 the licences
--
-- A EUROPEAN HUNTING LICENCE IS NOT A CARD, IT IS A SMALL STIFF-COVERED BOOKLET: cloth cover, a
-- crest, a brass eyelet for the lanyard, and inside a printed page with your animal on it and a
-- validating stamp. So it is ONE MODEL, standing open on the shelf, cover on the left and page on
-- the right, hinged at a spine in the middle (shop2 spec 2.4).
--
-- ONE FUNCTION, ONE ARGUMENT. The two licences are the SAME geometry with different furniture,
-- which is the older file's own rule -- *"a licence is a licence, and what tells them apart is the
-- animal"* -- extended with the colour of its cloth. Deer is burgundy and carries a red stag;
-- beater is loden and carries the horn and the orange band.
--
-- THE LEAVES ARE YAWED, AND IT IS THE ONE THING TO GET RIGHT (spec 2.4.1). The booklet stands open
-- at 160 degrees: the cover yaws +10 and the page yaws -10 about the spine. So *"0.034 studs proud
-- of the page"* is NOT a fixed `z` -- it is an offset along the leaf's OWN NORMAL. A flat world `z`
-- leaves the print sunk into the paper at one end of the page and floating off it at the other, and
-- the stag disappears behind its own tint block. The Designer built it that way first and the
-- screenshot is why that section exists; `.screenshots/228-before-licence-reddeer.png` is the same
-- failure in the model this one replaces, where the stag cannot be seen at all.
local LEAF = {
	cover = { yawDeg = 10, cx = -0.55 },
	page = { yawDeg = -10, cx = 0.55 },
}
local LEAF_Y, LEAF_Z = 0.73, 0.1

-- A POINT ON A LEAF, IN THE LEAF'S OWN FRAME: `dx` across it, `dy` up it, `lift` proud of its centre
-- plane. `Ry(t)` takes the leaf's own across-axis to `(cos t, 0, -sin t)` and its own normal to
-- `(sin t, 0, cos t)`, which is the whole of this function.
local function leaf(side: string, dx: number, dy: number, lift: number): Vector3
	local t = math.rad(LEAF[side].yawDeg)
	local c, s = math.cos(t), math.sin(t)
	return Vector3.new(LEAF[side].cx + dx * c + lift * s, LEAF_Y + dy, LEAF_Z - dx * s + lift * c)
end

type LeafOpts = {
	shape: Enum.PartType?,
	rot: Vector3?,
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	reflectance: number?,
}

-- ONE PART ON A LEAF. `rz` is the IN-PLANE turn; the leaf's own yaw is added for you, and the order
-- is right because `CFrame.Angles(0, yaw, rz)` is `Ry(yaw) * Rz(rz)` -- the in-plane turn first,
-- then the leaf. `opts.rot` overrides both, for the pieces (the eyelet, a horn's bell) that are
-- Cylinders and have to point along an axis of their own.
local function onLeaf(
	side: string,
	name: string,
	size: Vector3,
	dx: number,
	dy: number,
	lift: number,
	rz: number?,
	opts: LeafOpts
): Piece
	return {
		name = name,
		shape = opts.shape,
		size = size,
		at = leaf(side, dx, dy, lift),
		rot = opts.rot or Vector3.new(0, LEAF[side].yawDeg, rz or 0),
		color = opts.color,
		material = opts.material,
		transparency = opts.transparency,
		reflectance = opts.reflectance,
	}
end

-- A HUNTING HORN IN A LEAF'S OWN FRAME, centred at `(cx, cy)`, `r` studs across (spec 2.4.4).
--
-- A CRESCENT AND NOT A RING. Roblox has no torus, and a CLOSED ring with a cord across it reads as
-- a PROHIBITION SIGN -- the Designer drew that first. So the horn is nine bars on a 200-degree arc
-- that THICKENS as it sweeps, then a three-disc bell, a mouthpiece and ONE cord. Two cords across
-- the coil is the prohibition sign again.
local function horn(rows: { Piece }, prefix: string, side: string, cx: number, cy: number, lift: number, r: number)
	local RR, A0, A1, N = r * 0.38, 190, -10, 9
	-- THE TUBE: nine bars swept clockwise from the mouthpiece at 9 o'clock over the top to the bell
	-- at 5 o'clock. `rz = a` makes a bar tangent to the arc.
	for i = 0, N - 1 do
		local t = i / (N - 1)
		local a = A0 + (A1 - A0) * t
		local w = r * (0.065 + 0.085 * t)
		rows[#rows + 1] = onLeaf(
			side,
			string.format("%sTube%d", prefix, i + 1),
			Vector3.new(w, r * 0.195, w),
			cx + math.cos(math.rad(a)) * RR,
			cy + math.sin(math.rad(a)) * RR,
			lift,
			a,
			{
				color = if i > 5 then HORN_HI else HORN_BRASS,
				material = Enum.Material.Metal,
				reflectance = 0.14,
			}
		)
	end
	-- THE BELL: three discs continuing along the tangent at the arc's end, each wider than the last.
	local tx, ty = math.sin(math.rad(A1)), -math.cos(math.rad(A1))
	local ex, ey = cx + math.cos(math.rad(A1)) * RR, cy + math.sin(math.rad(A1)) * RR
	local bd = { 0.3, 0.46, 0.66 }
	for i = 1, 3 do
		rows[#rows + 1] = onLeaf(
			side,
			string.format("%sBell%d", prefix, i),
			Vector3.new(r * 0.105, r * bd[i], r * bd[i]),
			ex + tx * r * 0.135 * i,
			ey + ty * r * 0.135 * i,
			lift,
			nil,
			{
				shape = Enum.PartType.Cylinder,
				rot = Vector3.new(0, LEAF[side].yawDeg, A1 - 90),
				color = if i == 3 then HORN_HI else HORN_BRASS,
				material = Enum.Material.Metal,
				reflectance = 0.18,
			}
		)
	end
	-- THE MOUTHPIECE, back up the other end, and ONE cord at the throat.
	local mx, my = math.sin(math.rad(A0)), -math.cos(math.rad(A0))
	rows[#rows + 1] = onLeaf(
		side,
		prefix .. "Mouth",
		Vector3.new(r * 0.15, r * 0.125, r * 0.125),
		cx + math.cos(math.rad(A0)) * RR - mx * r * 0.14,
		cy + math.sin(math.rad(A0)) * RR - my * r * 0.14,
		lift,
		nil,
		{
			shape = Enum.PartType.Cylinder,
			rot = Vector3.new(0, LEAF[side].yawDeg, A0 - 90),
			color = HORN_HI,
			material = Enum.Material.Metal,
			reflectance = 0.2,
		}
	)
	rows[#rows + 1] = onLeaf(
		side,
		prefix .. "Cord",
		Vector3.new(r * 0.085, r * 0.3, r * 0.06),
		cx - RR * 0.4,
		cy - RR * 0.6,
		lift + r * 0.02,
		16,
		{ color = VEST_DEEP, material = Enum.Material.Fabric }
	)
	rows[#rows + 1] = onLeaf(
		side,
		prefix .. "CordTassel",
		Vector3.new(r * 0.1, r * 0.1, r * 0.07),
		cx - RR * 0.48,
		cy - RR * 1,
		lift + r * 0.02,
		nil,
		{ color = VEST_ORANGE, material = Enum.Material.Fabric }
	)
end

-- THE SHELL, IDENTICAL IN BOTH LICENCES: a spine with two brass bands, a cloth cover with an inset
-- panel, and a printed page -- head band, seven guilloche rules over a tint block, two field labels
-- with their ink, a signature in two strokes, a brass eyelet through the top outer corner and a wax
-- roundel over the bottom one. 34 parts.
--
-- THE STAMP'S TRANSPARENCY IS DELIBERATE: a stamp is ink ON paper, and a solid disc would look like
-- a sticker.
local function licenceShell(rows: { Piece }, cover: Color3, coverDark: Color3, stampColor: Color3)
	local metal = Enum.Material.Metal
	local fabric = Enum.Material.Fabric
	-- THE SPINE belongs to NEITHER leaf, so it is placed in world coordinates.
	rows[#rows + 1] = {
		name = "Spine",
		size = Vector3.new(0.11, 1.46, 0.3),
		at = Vector3.new(0, 0.73, 0),
		color = coverDark,
		material = fabric,
	}
	for _, band in ipairs({ { name = "SpineBandTop", y = 1.14 }, { name = "SpineBandLow", y = 0.32 } }) do
		rows[#rows + 1] = {
			name = band.name,
			size = Vector3.new(0.12, 0.05, 0.31),
			at = Vector3.new(0, band.y, 0),
			color = BRASS,
			material = metal,
			reflectance = 0.18,
		}
	end

	-- THE COVER.
	rows[#rows + 1] =
		onLeaf("cover", "CoverL", Vector3.new(1.06, 1.46, 0.06), 0, 0, 0, nil, { color = cover, material = fabric })
	rows[#rows + 1] = onLeaf(
		"cover",
		"CoverLInset",
		Vector3.new(0.92, 1.3, 0.016),
		0,
		0,
		0.034,
		nil,
		{ color = coverDark, material = fabric }
	)
	rows[#rows + 1] = onLeaf("cover", "CoverLRule", Vector3.new(0.96, 0.012, 0.018), 0, 0.59, 0.036, nil, {
		color = BRASS,
		material = metal,
		reflectance = 0.2,
	})

	-- THE PAGE.
	rows[#rows + 1] = onLeaf("page", "PageR", Vector3.new(1.06, 1.46, 0.05), 0, 0, 0, nil, { color = PAPER_WARM })
	rows[#rows + 1] = onLeaf(
		"page",
		"PageRBack",
		Vector3.new(1.06, 1.46, 0.016),
		0,
		0,
		-0.028,
		nil,
		{ color = cover, material = fabric }
	)
	rows[#rows + 1] = onLeaf(
		"page",
		"PageEdgeTop",
		Vector3.new(1.06, 0.014, 0.052),
		0,
		0.725,
		0,
		nil,
		{ color = Color3.fromHex("D8CDAE") }
	)
	rows[#rows + 1] = onLeaf(
		"page",
		"HeadBand",
		Vector3.new(1.06, 0.24, 0.02),
		0,
		0.6,
		0.03,
		nil,
		{ color = cover, material = fabric }
	)
	rows[#rows + 1] = onLeaf("page", "HeadRule", Vector3.new(1.06, 0.015, 0.022), 0, 0.465, 0.032, nil, {
		color = BRASS,
		material = metal,
		reflectance = 0.2,
	})
	rows[#rows + 1] = onLeaf(
		"page",
		"HeadInk1",
		Vector3.new(0.62, 0.055, 0.022),
		-0.13,
		0.625,
		0.034,
		nil,
		{ color = Color3.fromHex("EFE6D2") }
	)
	rows[#rows + 1] = onLeaf(
		"page",
		"HeadInk2",
		Vector3.new(0.38, 0.032, 0.022),
		-0.25,
		0.542,
		0.034,
		nil,
		{ color = Color3.fromHex("BFCBB8") }
	)
	rows[#rows + 1] =
		onLeaf("page", "TintBlock", Vector3.new(0.9, 0.86, 0.016), 0, 0.09, 0.03, nil, { color = PAPER_TINT })
	rows[#rows + 1] =
		onLeaf("page", "FieldLabel1", Vector3.new(0.24, 0.032, 0.018), -0.33, -0.27, 0.034, nil, { color = FIELD })
	rows[#rows + 1] =
		onLeaf("page", "FieldInk1", Vector3.new(0.52, 0.042, 0.018), -0.19, -0.33, 0.034, nil, { color = INK })
	rows[#rows + 1] =
		onLeaf("page", "FieldLabel2", Vector3.new(0.19, 0.032, 0.018), -0.35, -0.43, 0.034, nil, { color = FIELD })
	rows[#rows + 1] =
		onLeaf("page", "FieldInk2", Vector3.new(0.38, 0.042, 0.018), -0.26, -0.49, 0.034, nil, { color = INK })
	rows[#rows + 1] =
		onLeaf("page", "SigRule", Vector3.new(0.46, 0.01, 0.018), -0.23, -0.61, 0.034, nil, { color = FIELD })
	rows[#rows + 1] = onLeaf(
		"page",
		"Sig1",
		Vector3.new(0.3, 0.026, 0.02),
		-0.28,
		-0.565,
		0.038,
		2,
		{ color = Color3.fromHex("2A3E6B") }
	)
	rows[#rows + 1] = onLeaf(
		"page",
		"Sig2",
		Vector3.new(0.19, 0.026, 0.02),
		-0.34,
		-0.595,
		0.038,
		-2,
		{ color = Color3.fromHex("2A3E6B") }
	)

	-- THE EYELET. A `Cylinder`'s axis is X, so a disc LYING IN the leaf needs `rot = (0, leafYaw +
	-- 90, 0)` -- given explicitly rather than through `rz`.
	local pageYaw = LEAF.page.yawDeg
	rows[#rows + 1] = onLeaf("page", "Eyelet", Vector3.new(0.055, 0.115, 0.115), 0.43, 0.6, 0.018, nil, {
		shape = Enum.PartType.Cylinder,
		rot = Vector3.new(0, pageYaw + 90, 0),
		color = BRASS,
		material = metal,
		reflectance = 0.22,
	})
	rows[#rows + 1] = onLeaf("page", "EyeletHole", Vector3.new(0.07, 0.055, 0.055), 0.43, 0.6, 0.022, nil, {
		shape = Enum.PartType.Cylinder,
		rot = Vector3.new(0, pageYaw + 90, 0),
		color = Color3.fromHex("211C13"),
	})

	-- SEVEN GUILLOCHE RULES across the tint block -- the fine security hatching that makes a
	-- document look PRINTED rather than blank.
	for i = 1, 7 do
		rows[#rows + 1] = onLeaf(
			"page",
			string.format("Guilloche%d", i),
			Vector3.new(0.84, 0.008, 0.018),
			0,
			-0.25 + i * 0.105,
			0.033,
			nil,
			{ color = GUILLOCHE }
		)
	end

	-- THE VALIDATING ROUNDEL, half on the print, which is exactly where a real one lands.
	rows[#rows + 1] = onLeaf("page", "StampRing", Vector3.new(0.44, 0.44, 0.022), 0.29, -0.43, 0.035, nil, {
		shape = Enum.PartType.Ball,
		color = stampColor,
		transparency = 0.12,
	})
	rows[#rows + 1] = onLeaf("page", "StampVoid", Vector3.new(0.33, 0.33, 0.023), 0.29, -0.43, 0.038, nil, {
		shape = Enum.PartType.Ball,
		color = PAPER_WARM,
		transparency = 0.28,
	})
	rows[#rows + 1] = onLeaf("page", "StampBar", Vector3.new(0.4, 0.05, 0.02), 0.29, -0.43, 0.041, -16, {
		color = stampColor,
		transparency = 0.12,
	})
	rows[#rows + 1] = onLeaf("page", "StampDot", Vector3.new(0.09, 0.09, 0.02), 0.29, -0.31, 0.041, nil, {
		shape = Enum.PartType.Ball,
		color = stampColor,
		transparency = 0.12,
	})
end

-- THE DEER LICENCE'S FURNITURE: a brass crest with a stag's head on the cover, and the WHOLE ANIMAL
-- in silhouette on the page -- standing, on the tint block, because the stag is what you are buying.
-- 12 + 14 + 10 = 36 parts (spec 2.4.3).
--
-- THE ANTLERS ARE THE DETAIL THAT MAKES IT A RED STAG AND NOT A ROE, and the crown reaching `dy`
-- 0.68 BREAKS INTO THE HEAD BAND on purpose: that is what makes it read as a crest rather than as a
-- drawing in a box.
local DEER_CREST: { { name: string, w: number, h: number, dx: number, dy: number, rz: number? } } = {
	{ name = "CrestSkull", w = 0.15, h = 0.22, dx = 0, dy = 0.15 },
	{ name = "CrestMuzzle", w = 0.105, h = 0.095, dx = 0, dy = 0.025 },
	{ name = "CrestEarL", w = 0.085, h = 0.05, dx = -0.105, dy = 0.2, rz = 26 },
	{ name = "CrestEarR", w = 0.085, h = 0.05, dx = 0.105, dy = 0.2, rz = -26 },
	{ name = "CrestAntlerL", w = 0.034, h = 0.27, dx = -0.105, dy = 0.325, rz = 24 },
	{ name = "CrestAntlerR", w = 0.034, h = 0.27, dx = 0.105, dy = 0.325, rz = -24 },
	{ name = "CrestTineL1", w = 0.028, h = 0.13, dx = -0.185, dy = 0.325, rz = 58 },
	{ name = "CrestTineL2", w = 0.026, h = 0.1, dx = -0.185, dy = 0.425, rz = 44 },
	{ name = "CrestTineR1", w = 0.028, h = 0.13, dx = 0.185, dy = 0.325, rz = -58 },
	{ name = "CrestTineR2", w = 0.026, h = 0.1, dx = 0.185, dy = 0.425, rz = -44 },
}

local STAG_BODY: { { name: string, w: number, h: number, dx: number, dy: number, rz: number?, dark: boolean? } } = {
	{ name = "StagBody", w = 0.46, h = 0.21, dx = -0.19, dy = -0.04 },
	{ name = "StagRump", w = 0.17, h = 0.24, dx = -0.38, dy = -0.02 },
	{ name = "StagChest", w = 0.16, h = 0.23, dx = -0.01, dy = -0.05 },
	{ name = "StagNeck", w = 0.12, h = 0.26, dx = 0.09, dy = 0.1, rz = -22 },
	{ name = "StagHead", w = 0.21, h = 0.1, dx = 0.19, dy = 0.24, rz = -10 },
	{ name = "StagMuzzle", w = 0.085, h = 0.065, dx = 0.29, dy = 0.21, rz = -10, dark = true },
	{ name = "StagEar", w = 0.08, h = 0.048, dx = 0.12, dy = 0.29, rz = 24, dark = true },
	{ name = "StagTail", w = 0.06, h = 0.095, dx = -0.45, dy = 0.05, rz = 14, dark = true },
	{ name = "LegFF", w = 0.048, h = 0.28, dx = -0.01, dy = -0.31, rz = 4, dark = true },
	{ name = "LegFB", w = 0.045, h = 0.27, dx = -0.09, dy = -0.3, rz = -5, dark = true },
	{ name = "LegRF", w = 0.048, h = 0.18, dx = -0.35, dy = -0.25, rz = -8, dark = true },
	{ name = "LegRHock", w = 0.044, h = 0.16, dx = -0.38, dy = -0.38, rz = 7, dark = true },
	{ name = "LegRB", w = 0.044, h = 0.16, dx = -0.29, dy = -0.37, rz = 3, dark = true },
	{ name = "Ground", w = 0.72, h = 0.015, dx = -0.16, dy = -0.455, dark = true },
}

local STAG_ANTLER: { { name: string, w: number, h: number, dx: number, dy: number, rz: number } } = {
	{ name = "BeamL", w = 0.034, h = 0.3, dx = 0.13, dy = 0.41, rz = 26 },
	{ name = "BeamR", w = 0.034, h = 0.3, dx = 0.27, dy = 0.4, rz = -20 },
	{ name = "TineL1", w = 0.028, h = 0.13, dx = 0.05, dy = 0.35, rz = 62 },
	{ name = "TineL2", w = 0.028, h = 0.12, dx = 0.05, dy = 0.46, rz = 52 },
	{ name = "TineL3", w = 0.026, h = 0.1, dx = 0.06, dy = 0.54, rz = 44 },
	{ name = "TineL4", w = 0.024, h = 0.08, dx = 0.08, dy = 0.61, rz = 34 },
	{ name = "TineR1", w = 0.028, h = 0.13, dx = 0.35, dy = 0.34, rz = -58 },
	{ name = "TineR2", w = 0.028, h = 0.12, dx = 0.35, dy = 0.45, rz = -48 },
	{ name = "TineR3", w = 0.026, h = 0.1, dx = 0.34, dy = 0.53, rz = -40 },
	{ name = "TineR4", w = 0.024, h = 0.08, dx = 0.32, dy = 0.6, rz = -30 },
}

local function deerFurniture(rows: { Piece })
	local metal = Enum.Material.Metal
	local coverYaw = LEAF.cover.yawDeg
	rows[#rows + 1] = onLeaf("cover", "CrestDisc", Vector3.new(0.02, 0.5, 0.5), 0, 0.19, 0.042, nil, {
		shape = Enum.PartType.Cylinder,
		rot = Vector3.new(0, coverYaw + 90, 0),
		color = BRASS,
		material = metal,
		reflectance = 0.22,
	})
	rows[#rows + 1] = onLeaf("cover", "CrestField", Vector3.new(0.018, 0.4, 0.4), 0, 0.19, 0.052, nil, {
		shape = Enum.PartType.Cylinder,
		rot = Vector3.new(0, coverYaw + 90, 0),
		color = OXBLOOD,
		material = Enum.Material.Fabric,
	})
	for _, row in ipairs(DEER_CREST) do
		rows[#rows + 1] = onLeaf("cover", row.name, Vector3.new(row.w, row.h, 0.022), row.dx, row.dy, 0.062, row.rz, {
			color = BRASS,
			material = metal,
			reflectance = 0.22,
		})
	end
	for _, row in ipairs(STAG_BODY) do
		rows[#rows + 1] = onLeaf("page", row.name, Vector3.new(row.w, row.h, 0.018), row.dx, row.dy, 0.034, row.rz, {
			color = if row.dark then STAG_DARK else STAG_HIDE,
		})
	end
	for _, row in ipairs(STAG_ANTLER) do
		rows[#rows + 1] = onLeaf(
			"page",
			row.name,
			Vector3.new(row.w, row.h, 0.018),
			row.dx,
			row.dy,
			0.035,
			row.rz,
			{ color = STAG_DARK }
		)
	end
end

-- THE BEATER LICENCE'S FURNITURE: the orange band -- *"the one thing you see across the room, and
-- the same orange a beater wears"* -- and the horn twice, 0.80 across on the cover and 0.54 on the
-- page. 3 + 15 + 15 = 33 parts (spec 2.4.4).
--
-- `BandPage` IS A VERTICAL STRIPE down the page's inner edge: it is how the two licences differ at
-- a glance when the booklet is half-turned and the cover is edge-on.
local function beaterFurniture(rows: { Piece })
	local fabric = Enum.Material.Fabric
	rows[#rows + 1] = onLeaf("cover", "BandCover", Vector3.new(1.06, 0.2, 0.018), 0, -0.33, 0.036, nil, {
		color = VEST_ORANGE,
		material = fabric,
	})
	rows[#rows + 1] = onLeaf("cover", "BandCoverEdge", Vector3.new(1.06, 0.022, 0.02), 0, -0.22, 0.038, nil, {
		color = VEST_DEEP,
		material = fabric,
	})
	rows[#rows + 1] = onLeaf("page", "BandPage", Vector3.new(0.09, 1.46, 0.018), -0.46, 0, 0.03, nil, {
		color = VEST_ORANGE,
		material = fabric,
	})
	horn(rows, "CoverHorn", "cover", 0, 0.22, 0.058, 0.8)
	horn(rows, "PageHorn", "page", 0.09, 0.25, 0.04, 0.54)
end

local function buildLicence(parent: Model, kind: string)
	local deer = kind == "deer"
	local rows: { Piece } = {}
	licenceShell(
		rows,
		if deer then BURGUNDY else LODEN,
		if deer then OXBLOOD else LODEN_DARK,
		if deer then WAX else VEST_DEEP
	)
	if deer then
		deerFurniture(rows)
	else
		beaterFurniture(rows)
	end
	pieces(parent, rows)
end

-- ---------------------------------------------------------------- 2.5 the slug carton
--
-- WHAT WAS WRONG: a CLOSED box with three shells in front of it. The box is the packaging, not the
-- goods, and the three strays read as spares (`.screenshots/228-before-ammo-slug.png`).
--
-- WHAT IT IS NOW: a shotshell carton with TEN SHELLS STANDING IN IT, two rows of five, brass up;
-- the lid off and lying FLAT behind it, label up; and one shell lying loose across the front with
-- its primer to the camera. 66 parts (spec 2.5).
--
-- THE LID LIES FLAT AND DOES NOT SIT ON THE BOX. A lid slid back along the top is the first thing
-- anyone draws and it cantilevers half a stud into thin air and buries the shells it is meant to be
-- revealing. Flat behind, it hides nothing and its printed face is the one `SOLID_VIEW`'s 25
-- degrees of pitch looks straight down at.
--
-- THE PRINT IS ON THE `+z` WALL AND NOT THE `-z` ONE. `SOLID_VIEW` stands the camera at yaw 34 /
-- pitch 25, so it looks from `+x / +z` and the `-z` wall is the BACK of the model from here. The
-- `buildAmmoCrate` this replaces stencilled `-z` and nobody ever saw it.
local CARTON_X = { -0.52, -0.26, 0, 0.26, 0.52 }
local CARTON_Z = { -0.19, 0.19 }

local LID_PRINT: { Piece } = {
	{ name = "Lid", size = Vector3.new(1.46, 0.055, 0.9), at = Vector3.new(-0.1, 0.028, -0.92), color = LODEN },
	{
		name = "LidLipL",
		size = Vector3.new(1.46, 0.085, 0.045),
		at = Vector3.new(-0.089, 0.07, -1.36),
		color = CASE_GREEN,
	},
	{
		name = "LidLipR",
		size = Vector3.new(1.46, 0.085, 0.045),
		at = Vector3.new(-0.111, 0.07, -0.48),
		color = CASE_GREEN,
	},
	{ name = "LidLabel", size = Vector3.new(1.12, 0.012, 0.6), at = Vector3.new(-0.1, 0.058, -0.92), color = CREAM },
	{ name = "LidBar", size = Vector3.new(0.72, 0.014, 0.12), at = Vector3.new(-0.16, 0.066, -1.07), color = STAMP },
	{
		name = "LidRule",
		size = Vector3.new(1.08, 0.014, 0.016),
		at = Vector3.new(-0.1, 0.066, -0.91),
		color = BRASS,
		material = Enum.Material.Metal,
		reflectance = 0.2,
	},
	{ name = "LidInk1", size = Vector3.new(0.54, 0.014, 0.046), at = Vector3.new(-0.24, 0.066, -0.79), color = INK },
	{ name = "LidInk2", size = Vector3.new(0.34, 0.014, 0.034), at = Vector3.new(-0.34, 0.066, -0.71), color = FIELD },
	{ name = "LidSlug", size = Vector3.new(0.09, 0.014, 0.2), at = Vector3.new(0.36, 0.066, -0.9), color = STEEL_DK },
}

local LOOSE_SHELL: { Piece } = {
	{
		name = "LooseHull",
		size = Vector3.new(0.34, 0.165, 0.165),
		at = Vector3.new(-0.24, 0.085, 0.66),
		color = HULL_RED,
	},
	{
		name = "LooseCrimp",
		size = Vector3.new(0.03, 0.158, 0.158),
		at = Vector3.new(-0.41, 0.085, 0.705),
		color = HULL_CRIMP,
	},
	{
		name = "LooseHead",
		size = Vector3.new(0.115, 0.178, 0.178),
		at = Vector3.new(-0.02, 0.085, 0.605),
		color = HEAD_BRASS,
		material = Enum.Material.Metal,
		reflectance = 0.16,
	},
	{
		name = "LooseRim",
		size = Vector3.new(0.022, 0.192, 0.192),
		at = Vector3.new(0.045, 0.085, 0.588),
		color = HEAD_BRASS,
		material = Enum.Material.Metal,
		reflectance = 0.16,
	},
	-- FIVE PARTS' WORTH OF DETAIL IN ONE: it is the one circle that says CARTRIDGE rather than TUBE.
	{
		name = "LoosePrimer",
		size = Vector3.new(0.024, 0.07, 0.07),
		at = Vector3.new(0.058, 0.085, 0.585),
		color = STEEL,
		material = Enum.Material.Metal,
		reflectance = 0.2,
	},
}

-- ONE ROW OF A TABLE ABOVE, TURNED. The lid lies at -14 degrees so it is not square to the box and
-- the loose shell at -16 so it is not square to the shelf.
local function turned(row: Piece, yawDeg: number, shape: Enum.PartType?): Piece
	return {
		name = row.name,
		shape = shape,
		size = row.size,
		at = row.at,
		rot = Vector3.new(0, yawDeg, 0),
		color = row.color,
		material = row.material,
		transparency = row.transparency,
		reflectance = row.reflectance,
	}
end

local function buildSlugCarton(parent: Model)
	local metal = Enum.Material.Metal
	local rows: { Piece } = {
		{ name = "Base", size = Vector3.new(1.42, 0.07, 0.86), at = Vector3.new(0, 0.035, 0), color = LODEN },
		{ name = "WallNear", size = Vector3.new(1.42, 0.4, 0.055), at = Vector3.new(0, 0.27, 0.4), color = LODEN },
		{ name = "WallFar", size = Vector3.new(1.42, 0.4, 0.055), at = Vector3.new(0, 0.27, -0.4), color = LODEN },
		{
			name = "WallLeft",
			size = Vector3.new(0.055, 0.4, 0.86),
			at = Vector3.new(-0.68, 0.27, 0),
			color = CASE_GREEN,
		},
		{
			name = "WallRight",
			size = Vector3.new(0.055, 0.4, 0.86),
			at = Vector3.new(0.68, 0.27, 0),
			color = CASE_GREEN,
		},
		{ name = "Divider", size = Vector3.new(1.3, 0.24, 0.03), at = Vector3.new(0, 0.19, 0), color = CASE_GREEN },
		{
			name = "NearLabel",
			size = Vector3.new(1.1, 0.24, 0.016),
			at = Vector3.new(-0.06, 0.26, 0.432),
			color = CREAM,
		},
		{
			name = "NearRule",
			size = Vector3.new(1.06, 0.012, 0.018),
			at = Vector3.new(-0.06, 0.335, 0.437),
			color = BRASS,
			material = metal,
			reflectance = 0.2,
		},
		{ name = "NearBar", size = Vector3.new(0.6, 0.075, 0.018), at = Vector3.new(-0.26, 0.3, 0.437), color = STAMP },
		{ name = "NearInk1", size = Vector3.new(0.44, 0.038, 0.018), at = Vector3.new(-0.33, 0.2, 0.437), color = INK },
		{ name = "NearInk2", size = Vector3.new(0.26, 0.03, 0.018), at = Vector3.new(0.3, 0.2, 0.437), color = FIELD },
		{
			name = "NearSlug",
			size = Vector3.new(0.085, 0.145, 0.018),
			at = Vector3.new(0.42, 0.3, 0.437),
			color = STEEL_DK,
		},
	}

	-- TEN SHELLS, HEADS UP SO THE BRASS READS. Four parts each.
	local index = 0
	for _, z in ipairs(CARTON_Z) do
		for _, x in ipairs(CARTON_X) do
			index += 1
			rows[#rows + 1] = {
				name = string.format("Hull%d", index),
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(0.34, 0.165, 0.165),
				at = Vector3.new(x, 0.24, z),
				rot = Vector3.new(0, 0, 90),
				color = HULL_RED,
			}
			rows[#rows + 1] = {
				name = string.format("Crimp%d", index),
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(0.03, 0.158, 0.158),
				at = Vector3.new(x, 0.42, z),
				rot = Vector3.new(0, 0, 90),
				color = HULL_CRIMP,
			}
			rows[#rows + 1] = {
				name = string.format("Head%d", index),
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(0.115, 0.178, 0.178),
				at = Vector3.new(x, 0.49, z),
				rot = Vector3.new(0, 0, 90),
				color = HEAD_BRASS,
				material = metal,
				reflectance = 0.16,
			}
			rows[#rows + 1] = {
				name = string.format("Rim%d", index),
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(0.022, 0.192, 0.192),
				at = Vector3.new(x, 0.552, z),
				rot = Vector3.new(0, 0, 90),
				color = HEAD_BRASS,
				material = metal,
				reflectance = 0.16,
			}
		end
	end

	for _, row in ipairs(LID_PRINT) do
		rows[#rows + 1] = turned(row, -14, nil)
	end
	for _, row in ipairs(LOOSE_SHELL) do
		rows[#rows + 1] = turned(row, -16, Enum.PartType.Cylinder)
	end
	pieces(parent, rows)
end

-- ---------------------------------------------------------------- 2.6 the bandolier
--
-- WHY A BANDOLIER AND NOT A BIGGER CRATE. The crate this replaces was *"the SLUG box's own
-- vocabulary at a bigger size"* -- and that is the problem: on a shelf next to a slug carton it
-- reads as MORE SHELLS, which is a quantity and not an entitlement. A cartridge belt BUCKLED CLOSED
-- INTO A RING reads as NO END -- and it is a circle on a shelf of rectangles, the only silhouette
-- in this catalogue that is not a box (spec 2.6).
--
-- 16 LOOPS ON ITS OWN AND 10 INSIDE A PACKAGE. `THE FULL SEASON` covers six rows and one of them is
-- this; 82 parts inside a 1.42-stud thumbnail is six times the geometry for none of the picture.
-- THIS IS THE ONLY PLACE IN THIS FILE WHERE A MODEL KNOWS IT IS INSIDE A PACKAGE -- keep it that
-- way, and pass `nil` everywhere else.
local BELT_RX, BELT_RZ = 0.72, 0.5

-- THE BUCKLE, at `z = +0.50`: the front of the ring AND the side the camera is on. It is what turns
-- a crown into a belt.
local BUCKLE: { Piece } = {
	{
		name = "BuckleTongueBed",
		size = Vector3.new(0.42, 0.185, 0.17),
		at = Vector3.new(0, 0.0925, 0.52),
		color = LEATHER_HI,
		material = Enum.Material.Fabric,
	},
	{
		name = "BuckleFrameL",
		size = Vector3.new(0.046, 0.23, 0.2),
		at = Vector3.new(-0.17, 0.115, 0.53),
		color = BRASS,
		material = Enum.Material.Metal,
		reflectance = 0.18,
	},
	{
		name = "BuckleFrameR",
		size = Vector3.new(0.046, 0.23, 0.2),
		at = Vector3.new(0.17, 0.115, 0.53),
		color = BRASS,
		material = Enum.Material.Metal,
		reflectance = 0.18,
	},
	{
		name = "BuckleFrameT",
		size = Vector3.new(0.39, 0.23, 0.044),
		at = Vector3.new(0, 0.115, 0.615),
		color = BRASS,
		material = Enum.Material.Metal,
		reflectance = 0.18,
	},
	{
		name = "BuckleFrameB",
		size = Vector3.new(0.39, 0.23, 0.044),
		at = Vector3.new(0, 0.115, 0.445),
		color = BRASS,
		material = Enum.Material.Metal,
		reflectance = 0.18,
	},
	{
		name = "BucklePin",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.195, 0.04, 0.04),
		at = Vector3.new(0, 0.115, 0.53),
		rot = Vector3.new(0, 0, 90),
		color = BRASS,
		material = Enum.Material.Metal,
		reflectance = 0.18,
	},
	{
		name = "BuckleTip",
		size = Vector3.new(0.22, 0.155, 0.135),
		at = Vector3.new(0.31, 0.0925, 0.495),
		rot = Vector3.new(0, 18, 0),
		color = LEATHER_HI,
		material = Enum.Material.Fabric,
	},
}

local function buildBandolier(parent: Model, detail: string?)
	local n = if detail == "lite" then 10 else 16
	local metal = Enum.Material.Metal
	local fabric = Enum.Material.Fabric
	local rows: { Piece } = {}
	for i = 1, n do
		local deg = (i - 1) * (360 / n)
		-- THE BUCKLE'S GAP, at the front of the ring. A loop under the buckle is a loop you drew
		-- inside a brass frame.
		if math.abs(((deg - 90) % 360 + 540) % 360 - 180) >= (360 / n) * 0.6 then
			local a = math.rad(deg)
			local x, z = math.cos(a) * BELT_RX, math.sin(a) * BELT_RZ
			-- THE TANGENT, FROM THE OVAL'S OWN DERIVATIVE and not from the angle -- which would
			-- leave every segment on the long sides turned a few degrees wrong.
			local tan = math.deg(math.atan2(math.cos(a) * BELT_RZ, -math.sin(a) * BELT_RX))
			local turn = Vector3.new(0, tan, 0)
			local standing = Vector3.new(0, tan, 90)
			rows[#rows + 1] = {
				name = string.format("Strap%d", i),
				size = Vector3.new(0.31, 0.205, 0.155),
				at = Vector3.new(x, 0.1025, z),
				rot = turn,
				color = LEATHER,
				material = fabric,
			}
			rows[#rows + 1] = {
				name = string.format("Loop%d", i),
				size = Vector3.new(0.09, 0.235, 0.175),
				at = Vector3.new(x, 0.115, z),
				rot = turn,
				color = LEATHER_DK,
				material = fabric,
			}
			rows[#rows + 1] = {
				name = string.format("Hull%d", i),
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(0.3, 0.15, 0.15),
				at = Vector3.new(x, 0.3, z),
				rot = standing,
				color = HULL_RED,
			}
			rows[#rows + 1] = {
				name = string.format("Head%d", i),
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(0.115, 0.168, 0.168),
				at = Vector3.new(x, 0.505, z),
				rot = standing,
				color = HEAD_BRASS,
				material = metal,
				reflectance = 0.16,
			}
			rows[#rows + 1] = {
				name = string.format("Rim%d", i),
				shape = Enum.PartType.Cylinder,
				size = Vector3.new(0.02, 0.182, 0.182),
				at = Vector3.new(x, 0.567, z),
				rot = standing,
				color = HEAD_BRASS,
				material = metal,
				reflectance = 0.16,
			}
		end
	end
	pieces(parent, rows)
	pieces(parent, BUCKLE)
end

-- ---------------------------------------------------------------- 2.7 the hunter's pin
--
-- WHAT IT IS. `ALWAYS HUNTER` is a STANDING and not an object, so what is sold is the TOKEN of a
-- standing: an enamelled lapel pin, still pinned through the little loden card it came on, the way
-- a pin is actually sold. A pin is small, jewelled and personal; the badge it replaces read as a
-- flag for a team, which is the wrong idea now that the thing is a CHOICE. 25 parts (spec 2.7).
--
-- `z = 0.215` IS NOT ARBITRARY. The enamel is an ellipsoid: its surface at the stag's height is at
-- `z` about 0.19, so anything laid at 0.185 is half buried and renders as scribble. Every motif on a
-- curved face has to clear that face's OWN BULGE at the point it sits -- measure it, do not guess it.
local PIN_STAG: { { name: string, w: number, h: number, x: number, y: number, rz: number? } } = {
	{ name = "PinSkull", w = 0.145, h = 0.22, x = 0, y = 0.83 },
	{ name = "PinMuzzle", w = 0.1, h = 0.1, x = 0, y = 0.695 },
	{ name = "PinEarL", w = 0.085, h = 0.05, x = -0.1, y = 0.89, rz = 26 },
	{ name = "PinEarR", w = 0.085, h = 0.05, x = 0.1, y = 0.89, rz = -26 },
	{ name = "PinBeamL", w = 0.036, h = 0.26, x = -0.1, y = 1, rz = 22 },
	{ name = "PinBeamR", w = 0.036, h = 0.26, x = 0.1, y = 1, rz = -22 },
	{ name = "PinTineL1", w = 0.03, h = 0.12, x = -0.18, y = 1.01, rz = 58 },
	{ name = "PinTineL2", w = 0.028, h = 0.095, x = -0.175, y = 1.11, rz = 42 },
	{ name = "PinTineR1", w = 0.03, h = 0.12, x = 0.18, y = 1.01, rz = -58 },
	{ name = "PinTineR2", w = 0.028, h = 0.095, x = 0.175, y = 1.11, rz = -42 },
}

local function buildHunterPin(parent: Model)
	local metal = Enum.Material.Metal
	local fabric = Enum.Material.Fabric
	local rows: { Piece } = {
		{
			name = "Card",
			size = Vector3.new(1.02, 1.3, 0.05),
			at = Vector3.new(0, 0.65, 0),
			color = LODEN,
			material = fabric,
		},
		{
			name = "CardEdge",
			size = Vector3.new(0.9, 1.18, 0.014),
			at = Vector3.new(0, 0.65, 0.031),
			color = LODEN_DARK,
			material = fabric,
		},
		{
			name = "CardRule",
			size = Vector3.new(0.94, 0.012, 0.016),
			at = Vector3.new(0, 1.2, 0.033),
			color = BRASS,
			material = metal,
			reflectance = 0.2,
		},
		{
			name = "CardRule2",
			size = Vector3.new(0.94, 0.012, 0.016),
			at = Vector3.new(0, 0.18, 0.033),
			color = BRASS,
			material = metal,
			reflectance = 0.2,
		},
		{ name = "CardInk1", size = Vector3.new(0.56, 0.042, 0.016), at = Vector3.new(0, 0.112, 0.033), color = CREAM },
		{ name = "CardInk2", size = Vector3.new(0.34, 0.028, 0.016), at = Vector3.new(0, 0.058, 0.033), color = FIELD },
		{
			name = "PinSlot1",
			size = Vector3.new(0.05, 0.016, 0.018),
			at = Vector3.new(-0.22, 0.37, 0.034),
			color = Color3.fromHex("14200F"),
			material = fabric,
		},
		{
			name = "PinSlot2",
			size = Vector3.new(0.05, 0.016, 0.018),
			at = Vector3.new(0.22, 0.37, 0.034),
			color = Color3.fromHex("14200F"),
			material = fabric,
		},
		-- THE PIN. Note the `z` ladder: the ENAMEL FACE STANDS PROUD OF THE BRASS RIM, so the brass
		-- shows as a border at the silhouette and nowhere else. `PartType.Ball` with an unequal size
		-- is an ellipsoid, which is how the oval is round without a mesh.
		{
			name = "PinStem",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.46, 0.035, 0.035),
			at = Vector3.new(0, 0.5, 0.012),
			rot = Vector3.new(0, 0, 90),
			color = BRASS,
			material = metal,
			reflectance = 0.2,
		},
		{
			name = "PinClasp",
			size = Vector3.new(0.14, 0.09, 0.05),
			at = Vector3.new(0, 0.3, 0.01),
			color = BRASS,
			material = metal,
			reflectance = 0.2,
		},
		{
			name = "PinRim",
			shape = Enum.PartType.Ball,
			size = Vector3.new(0.88, 1.04, 0.19),
			at = Vector3.new(0, 0.75, 0.08),
			color = BRASS,
			material = metal,
			reflectance = 0.22,
		},
		{
			name = "PinFace",
			shape = Enum.PartType.Ball,
			size = Vector3.new(0.8, 0.96, 0.17),
			at = Vector3.new(0, 0.75, 0.105),
			color = ENAMEL,
			-- 0.06 AND NOT THE SPEC'S 0.30, MEASURED (rule 5, `.screenshots/228-after-role-
			-- alwayshunter.png` at 0.30): a `ViewportFrame` has no sky to reflect, so `Reflectance`
			-- blends the colour toward the frame's own light -- and at 0.30 the dark green enamel
			-- came out TAN, the same tone as the brass rim and the brass stag standing on it, so
			-- the whole pin read as one flat disc. The glint is worth 0.06 and nothing more. The
			-- BRASS pieces are unaffected: brass blended toward a warm light still reads as brass,
			-- which is why every `Metal` reflectance in this file is the spec's.
			reflectance = 0.06,
		},
		{
			name = "PinBand",
			size = Vector3.new(0.5, 0.145, 0.07),
			at = Vector3.new(0, 0.495, 0.168),
			color = BLAZE,
			-- 0 for the same reason: at 0.10 the blaze band came out salmon.
		},
		{
			name = "PinBandEdge",
			size = Vector3.new(0.5, 0.02, 0.072),
			at = Vector3.new(0, 0.578, 0.17),
			color = Color3.fromHex("8E3F0C"),
		},
	}
	-- THE STAG'S HEAD ON THE ENAMEL -- the same crest the deer licence's cover carries, so the two
	-- read as one house.
	for _, row in ipairs(PIN_STAG) do
		rows[#rows + 1] = {
			name = row.name,
			size = Vector3.new(row.w, row.h, 0.03),
			at = Vector3.new(row.x, row.y, 0.215),
			rot = if row.rz ~= nil then Vector3.new(0, 0, row.rz) else nil,
			color = BRASS,
			material = metal,
			reflectance = 0.22,
		}
	end
	rows[#rows + 1] = {
		name = "PinEye",
		size = Vector3.new(0.034, 0.034, 0.034),
		at = Vector3.new(-0.042, 0.865, 0.232),
		color = ENAMEL,
	}
	pieces(parent, rows)
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

-- ---------------------------------------------------------------- 2.8 high-seat access
--
-- OUR HIGH SEAT, IN MINIATURE, READ OFF `HighSeats.DIMS` AND `HighSeats.COLORS` -- the SAME module
-- `HighSeats.plan` builds the real stands on the drive line out of. Nothing here is a second
-- measurement of the seat: every number below is that module's, times one scale.
--
-- THE DIRECTOR'S OVERRIDE, 2026-10-21. The shop2 spec's section 2.8 draws a CLOSED BOX BLIND -- the
-- German `Kanzel`, with a roof, a shooting window and side walls -- because the Designer had not
-- seen our stands. OURS ARE OPEN: four posts, a plank deck, one board round it at a seated man's
-- chest, a ladder, and NO ROOF (`HighSeats`' own header). Karen, 2026-10-20: *"we stay what you
-- have builded"*. So the roof, the walls, the window cut-outs and the dark interior are DROPPED and
-- this is our seat. What is KEPT from the spec is the thing it is actually selling -- a brass key
-- tag hung off a rung, because what the row grants is ACCESS -- and `TALL_VIEW`.
--
-- `TALL_VIEW` STANDS THE CAMERA AT YAW 30, so it sees `+x` and `+z`, and the LADDER has to be on
-- `+x` or it is behind the thing it is part of. The real seat's ladder is on its SOUTH face (`-z`,
-- behind the hunter, who faces the drive at `+z`), so `seatAt` turns the whole miniature a quarter
-- -- it is our seat, seen from a different corner, and not a seat with its ladder moved.
--
-- WHY `TALL_VIEW` AND NOT `SOLID_VIEW`: the thing is 2.3 studs tall and about 1 wide, and
-- `SOLID_VIEW`'s 25 degrees of pitch looks DOWN on it and turns the whole stand into a deck.
-- `.screenshots/228-before-access-highseat.png` is that picture.
-- THE MINIATURE IS THIS TALL, and the scale follows from it: a real seat is `DECK_RISE + RAIL_RISE`
-- studs from its feet to the top of its rail, and the spec's envelope for this picture is 2.28.
local SEAT_TALL_STUDS = 2.28
local SEAT_REAL_TALL = HighSeats.DIMS.DECK_RISE_STUDS + HighSeats.DIMS.RAIL_RISE_STUDS
local SEAT_SCALE = SEAT_TALL_STUDS / SEAT_REAL_TALL

-- FROM THE REAL SEAT'S FRAME INTO THE MINIATURE'S: scaled, and turned a quarter about Y so the
-- ladder (real `-z`) faces `+x`, where `TALL_VIEW`'s camera is. `y` is measured from the seat's
-- FEET, which `HighSeats.plan` calls `footY`.
local function seatAt(x: number, y: number, z: number): Vector3
	return Vector3.new(-z * SEAT_SCALE, y * SEAT_SCALE, x * SEAT_SCALE)
end

-- A REAL SIZE THROUGH THE SAME QUARTER TURN: `x` and `z` swap.
local function seatSize(sx: number, sy: number, sz: number): Vector3
	return Vector3.new(sz * SEAT_SCALE, sy * SEAT_SCALE, sx * SEAT_SCALE)
end

local function buildHighSeat(parent: Model)
	local dims = HighSeats.DIMS
	local colors = HighSeats.COLORS
	local wood = Enum.Material.Wood
	local metal = Enum.Material.Metal
	-- THE REAL SEAT'S OWN ARITHMETIC, with the feet at 0: the deck's top is `DECK_RISE` up, the four
	-- legs run on past it to `RAIL_RISE` because the legs ARE the rail posts, and the rail board's
	-- top is that same number.
	local deckTop = dims.DECK_RISE_STUDS
	local legTop = deckTop + dims.RAIL_RISE_STUDS
	local inset = dims.LEG_INSET_STUDS
	local plane = dims.RAIL_PLANE_STUDS
	local tall = dims.RAIL_BOARD_TALL_STUDS
	local thick = dims.RAIL_BOARD_THICK_STUDS
	local width = dims.DECK_SIZE.X
	local railY = deckTop + dims.RAIL_RISE_STUDS - tall / 2
	local rows: { Piece } = {}

	-- THE FOUR LEGS, which are also the rail posts, so they all end at ONE number.
	local legIndex = 0
	for _, dx in ipairs({ -inset, inset }) do
		for _, dz in ipairs({ -inset, inset }) do
			legIndex += 1
			rows[#rows + 1] = {
				name = string.format("Leg%d", legIndex),
				size = seatSize(dims.LEG_SECTION_STUDS, legTop, dims.LEG_SECTION_STUDS),
				at = seatAt(dx, legTop / 2, dz),
				color = colors.TIMBER,
				material = wood,
			}
		end
	end

	-- ONE GIRT, ON THE SOUTH FACE, AND NOT FOUR -- the real seat's own decision (the Director's
	-- look, 2026-10-20: four girts read as a steel pylon). `JOINT` because it sits in the seat's own
	-- shadow.
	rows[#rows + 1] = {
		name = "Girt",
		size = seatSize(inset * 2 + dims.LEG_SECTION_STUDS, dims.GIRT_SECTION_STUDS, dims.GIRT_SECTION_STUDS),
		at = seatAt(0, dims.GIRT_RISE_STUDS, -inset),
		color = colors.JOINT,
		material = wood,
	}

	-- THE TWO BRACES, one diagonal on each side face. In the real seat they run from
	-- `(dx, 1, -inset)` to `(dx, DECK_RISE - 1.5, +inset)`; the quarter turn puts that run in the
	-- miniature's own XY plane, so one `rz` draws it.
	local braceLow, braceHigh = 1, dims.DECK_RISE_STUDS - 1.5
	local braceRun = seatAt(0, braceHigh, inset) - seatAt(0, braceLow, -inset)
	local braceDeg = math.deg(math.atan2(braceRun.Y, braceRun.X))
	for _, dx in ipairs({ -inset, inset }) do
		rows[#rows + 1] = {
			name = if dx < 0 then "BraceW" else "BraceE",
			size = Vector3.new(
				braceRun.Magnitude,
				dims.BRACE_SECTION_STUDS * SEAT_SCALE,
				dims.BRACE_SECTION_STUDS * SEAT_SCALE
			),
			at = seatAt(dx, (braceLow + braceHigh) / 2, 0),
			rot = Vector3.new(0, 0, braceDeg),
			color = colors.JOINT,
			material = wood,
		}
	end

	-- THE DECK, whose TOP face is `deckTop`.
	rows[#rows + 1] = {
		name = "Deck",
		size = seatSize(dims.DECK_SIZE.X, dims.DECK_SIZE.Y, dims.DECK_SIZE.Z),
		at = seatAt(0, deckTop - dims.DECK_SIZE.Y / 2, 0),
		color = colors.DECK,
		material = Enum.Material.WoodPlanks,
	}

	-- THE RAIL: one board on each face, with a gap in the south one for the ladder -- the same five
	-- boards `HighSeats.plan` lays, with the same stub arithmetic.
	local stubWidth = (width - dims.LADDER_GAP_STUDS) / 2
	local stubCentre = dims.LADDER_GAP_STUDS / 2 + stubWidth / 2
	rows[#rows + 1] = {
		name = "RailN",
		size = seatSize(width, tall, thick),
		at = seatAt(0, railY, plane),
		color = colors.TIMBER,
		material = wood,
	}
	for _, row in ipairs({ { name = "RailE", dx = plane }, { name = "RailW", dx = -plane } }) do
		rows[#rows + 1] = {
			name = row.name,
			size = seatSize(thick, tall, width - thick * 2),
			at = seatAt(row.dx, railY, 0),
			color = colors.TIMBER,
			material = wood,
		}
	end
	for _, row in ipairs({ { name = "RailSE", dx = stubCentre }, { name = "RailSW", dx = -stubCentre } }) do
		rows[#rows + 1] = {
			name = row.name,
			size = seatSize(stubWidth, tall, thick),
			at = seatAt(row.dx, railY, -plane),
			color = colors.TIMBER,
			material = wood,
		}
	end

	-- THE LADDER. The real one is a `TrussPart` and the climb is the engine's own `Climbing` state;
	-- a `TrussPart`'s lattice is sized in STUDS, so at a seventh of full size it would render as a
	-- solid block -- which is why a picture of it is two rails and its rungs, at the truss's own
	-- 2-stud width and 2-stud rung pitch. Its foot is on the shelf and its top runs
	-- `LADDER_OVER_DECK_STUDS` past the deck, exactly as the real one does.
	local ladderTop = deckTop + dims.LADDER_OVER_DECK_STUDS
	local ladderZ = dims.LADDER_OFFSET_STUDS - dims.LADDER_SIZE_STUDS / 2
	local half = dims.LADDER_SIZE_STUDS / 2
	for _, dx in ipairs({ -half, half }) do
		rows[#rows + 1] = {
			name = if dx < 0 then "LadderRail1" else "LadderRail2",
			size = seatSize(0.3, ladderTop, 0.3),
			at = seatAt(dx, ladderTop / 2, ladderZ),
			color = colors.TIMBER,
			material = wood,
		}
	end
	local rung = 0
	for y = 1, ladderTop, 2 do
		rung += 1
		rows[#rows + 1] = {
			name = string.format("Rung%d", rung),
			size = seatSize(dims.LADDER_SIZE_STUDS, 0.22, 0.22),
			at = seatAt(0, y, ladderZ),
			color = colors.TIMBER,
			material = wood,
		}
	end

	-- THE KEY TAG, the one thing kept from the spec's drawing: what the row grants is ACCESS, so the
	-- model says so. It hangs off the ladder's OUTER face, which the camera at yaw 30 is looking
	-- straight at, and a `Cylinder`'s axis is X -- so the ring faces the camera with no `rot` at all.
	local faceX = (-ladderZ + 0.15) * SEAT_SCALE
	for _, row in ipairs({
		{
			name = "KeyRing",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.022, 0.145, 0.145),
			at = Vector3.new(faceX, 0.72, 0),
			color = BRASS,
			material = metal,
			reflectance = 0.22,
		},
		{
			name = "KeyRingVoid",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.026, 0.085, 0.085),
			at = Vector3.new(faceX + 0.005, 0.72, 0),
			color = Color3.fromHex("161310"),
		},
		{
			name = "KeyFob",
			size = Vector3.new(0.022, 0.28, 0.19),
			at = Vector3.new(faceX + 0.003, 0.55, 0),
			rot = Vector3.new(0, 0, 6),
			color = LODEN,
			material = Enum.Material.Fabric,
		},
		{
			name = "KeyFobInk",
			size = Vector3.new(0.024, 0.034, 0.11),
			at = Vector3.new(faceX + 0.016, 0.6, 0),
			rot = Vector3.new(0, 0, 6),
			color = CREAM,
		},
		{
			name = "KeyTag",
			size = Vector3.new(0.02, 0.22, 0.06),
			at = Vector3.new(faceX + 0.005, 0.3, 0),
			rot = Vector3.new(0, 0, 6),
			color = BRASS,
			material = metal,
			reflectance = 0.22,
		},
	}) do
		rows[#rows + 1] = row
	end

	pieces(parent, rows)
end

-- ---------------------------------------------------------------- 2.9 the packages
--
-- KEEP THE RULE AND CHANGE THE STAGING. The rule is right and stays: a package draws
-- `ShopDisplay.build(covered)` for each of its contents, so there is ONE drawing per item, a package
-- can never show something it does not contain, and a row that gains a picture gains it inside every
-- package that covers it. What changes is what the goods stand ON -- a bare board says INVENTORY and
-- a lined wooden case with its lid open says A PACKAGE (spec 2.9).
--
-- THE LID IS HINGED AT THE BACK (`-z`) AND LEANS AWAY FROM THE CAMERA AT 72 DEGREES, so the camera
-- on `+x / +z` is looking at its INSIDE, which is where the label is. Hinge it at the front and you
-- have built a door that hides the goods.
--
-- THE STRAP IS THE PACKAGE'S ONE SIGNATURE, so the three are told apart before you read the name.
local BUNDLE_SPREAD = 1.62
local BUNDLE_ITEM_STUDS = 1.42
local LID_DEG = 72

local STRAP_COLOR: { [string]: Color3 } = {
	[ShopData.ITEM.BUNDLE_HIDE] = LODEN,
	[ShopData.ITEM.BUNDLE_MARKSMAN] = BURGUNDY,
	[ShopData.ITEM.BUNDLE_SEASON] = BLAZE,
}

-- THE MODEL'S WORLD-ALIGNED BOX, computed over its own parts. `Model:GetBoundingBox` returns a box
-- in the PRIMARY PART'S basis, and several of these models' first part is a rotated one (a strap on
-- the bandolier's ring, a yawed licence leaf) -- so that box is neither axis-aligned nor the one a
-- shelf has to stand the thing on. PURE.
local function worldBox(model: Model): (Vector3, Vector3)
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = Vector3.new(-math.huge, -math.huge, -math.huge)
	local any = false
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			any = true
			local cf, size = part.CFrame, part.Size
			local reach = Vector3.new(
				math.abs(cf.RightVector.X * size.X)
					+ math.abs(cf.UpVector.X * size.Y)
					+ math.abs(cf.LookVector.X * size.Z),
				math.abs(cf.RightVector.Y * size.X)
					+ math.abs(cf.UpVector.Y * size.Y)
					+ math.abs(cf.LookVector.Y * size.Z),
				math.abs(cf.RightVector.Z * size.X)
					+ math.abs(cf.UpVector.Z * size.Y)
					+ math.abs(cf.LookVector.Z * size.Z)
			) / 2
			lo = lo:Min(cf.Position - reach)
			hi = hi:Max(cf.Position + reach)
		end
	end
	if not any then
		return Vector3.zero, Vector3.one
	end
	return (lo + hi) / 2, hi - lo
end

local function buildBundle(parent: Model, id: string)
	local row = ShopData.anyRow(id)
	local covers = (row and row.covers) or {}
	local drawable: { string } = {}
	for _, covered in ipairs(covers) do
		if ShopDisplay.knows(covered) then
			table.insert(drawable, covered)
		end
	end
	local w = math.max(1.5, #drawable * BUNDLE_SPREAD + 0.4)
	local wood = Enum.Material.Wood
	local planks = Enum.Material.WoodPlanks
	local fabric = Enum.Material.Fabric
	local metal = Enum.Material.Metal
	local strap = STRAP_COLOR[id] or LODEN

	-- THE LID'S OWN FRAME. `rot = (72, 0, 0)` takes the lid's local `+y` -- its inner face's normal
	-- -- to `(0, cos 72, sin 72)`, which points up and TOWARD the camera, and its local `-z` to
	-- `(0, sin 72, -cos 72)`, which is the way it leans back from the hinge.
	local rad = math.rad(LID_DEG)
	local up = Vector3.new(0, math.cos(rad), math.sin(rad))
	local lean = Vector3.new(0, math.sin(rad), -math.cos(rad))
	local lidAt = Vector3.new(0, 0.3, -0.38) + lean * 0.31
	local lidTurn = Vector3.new(LID_DEG, 0, 0)
	local function onLid(d: number): Vector3
		return lidAt + up * d
	end

	pieces(parent, {
		{
			name = "CaseFloor",
			size = Vector3.new(w, 0.08, 0.76),
			at = Vector3.new(0, 0.04, 0),
			color = TIMBER_DARK,
			material = planks,
		},
		{
			name = "CaseLining",
			size = Vector3.new(w - 0.18, 0.016, 0.62),
			at = Vector3.new(0, 0.088, 0),
			color = LODEN,
			material = fabric,
		},
		{
			name = "CaseNear",
			size = Vector3.new(w, 0.3, 0.07),
			at = Vector3.new(0, 0.23, 0.38),
			color = TIMBER,
			material = wood,
		},
		{
			name = "CaseBack",
			size = Vector3.new(w, 0.3, 0.07),
			at = Vector3.new(0, 0.23, -0.38),
			color = TIMBER,
			material = wood,
		},
		{
			name = "CaseLeft",
			size = Vector3.new(0.07, 0.3, 0.76),
			at = Vector3.new(-w / 2 + 0.035, 0.23, 0),
			color = TIMBER_DARK,
			material = wood,
		},
		{
			name = "CaseRight",
			size = Vector3.new(0.07, 0.3, 0.76),
			at = Vector3.new(w / 2 - 0.035, 0.23, 0),
			color = TIMBER_DARK,
			material = wood,
		},
		{
			name = "CaseLid",
			size = Vector3.new(w, 0.055, 0.62),
			at = lidAt,
			rot = lidTurn,
			color = TIMBER,
			material = wood,
		},
		{
			name = "CaseLidLining",
			size = Vector3.new(w - 0.16, 0.014, 0.54),
			at = onLid(0.036),
			rot = lidTurn,
			color = LODEN,
			material = fabric,
		},
		{
			name = "CaseLidLabel",
			size = Vector3.new(0.78, 0.012, 0.38),
			at = onLid(0.048),
			rot = lidTurn,
			color = CREAM,
		},
		{
			name = "CaseLidRule",
			size = Vector3.new(0.74, 0.012, 0.014),
			at = onLid(0.056),
			rot = lidTurn,
			color = BRASS,
			material = metal,
			reflectance = 0.2,
		},
		{
			name = "CaseLidInk1",
			size = Vector3.new(0.5, 0.014, 0.045),
			at = onLid(0.058) + Vector3.new(-0.09, 0.016, 0.005),
			rot = lidTurn,
			color = INK,
		},
		{
			name = "CaseLidInk2",
			size = Vector3.new(0.36, 0.014, 0.034),
			at = onLid(0.058) + Vector3.new(-0.16, -0.03, -0.01),
			rot = lidTurn,
			color = FIELD,
		},
		-- THE STRAP AND THE PLATE ARE ON THE `+z` WALL for the same reason the carton's print is:
		-- that is the wall the camera is on.
		{
			name = "Strap",
			size = Vector3.new(w + 0.06, 0.105, 0.03),
			at = Vector3.new(0, 0.23, 0.418),
			color = strap,
			material = fabric,
		},
		{
			name = "StrapBuckle",
			size = Vector3.new(0.11, 0.15, 0.045),
			at = Vector3.new(w / 4, 0.23, 0.432),
			color = BRASS,
			material = metal,
			reflectance = 0.18,
		},
		{
			name = "PlateBed",
			size = Vector3.new(0.48, 0.16, 0.016),
			at = Vector3.new(-w / 4, 0.23, 0.424),
			color = LODEN,
			material = fabric,
		},
		{
			name = "Plate",
			size = Vector3.new(0.42, 0.115, 0.018),
			at = Vector3.new(-w / 4, 0.23, 0.43),
			color = BRASS,
			material = metal,
			reflectance = 0.22,
		},
	})

	-- THE CONTENTS, THROUGH `ShopDisplay.build` exactly as before -- so a package draws EXACTLY the
	-- model that row draws on its own page. It cannot recurse: `rowsOk` I7 refuses a package that
	-- covers a package. What is new is that they stand ON THE LINING, each a little yawed so the row
	-- is not a parade, and at 1.42 studs rather than 1.15 so the GOODS are the picture and the case
	-- is the frame.
	local span = (#drawable - 1) * BUNDLE_SPREAD
	for index, covered in ipairs(drawable) do
		local piece = ShopDisplay.build(covered, if covered == ShopData.ITEM.UNLIMITED_AMMO then "lite" else nil)
		if piece ~= nil then
			piece.Name = string.format("Part%d", index)
			local _, before = worldBox(piece)
			local tallest = math.max(before.X, before.Y, before.Z)
			local scale = if tallest > 0 then math.clamp(BUNDLE_ITEM_STUDS / tallest, 0.05, 1) else 1
			piece:ScaleTo(scale)
			-- MEASURED AGAIN AFTER THE SCALE, and moved by its BOX and not by its pivot: the pivot
			-- is whichever part happened to be made first, which for a yawed licence leaf or a
			-- bandolier strap is neither the model's centre nor its foot.
			local centre, size = worldBox(piece)
			local at = Vector3.new(-span / 2 + (index - 1) * BUNDLE_SPREAD, 0.096 + size.Y / 2, 0)
			local yaw = math.rad(if index % 2 == 0 then 14 else -11)
			piece:PivotTo(CFrame.new(at) * CFrame.Angles(0, yaw, 0) * CFrame.new(-centre) * piece:GetPivot())
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
local DRAW: { [string]: { view: View, build: (Model, string, string?) -> () } } = {
	[ShopData.ITEM.SEMIAUTO] = {
		view = RIFLE_VIEW,
		build = function(model: Model, _id: string)
			buildSemiAuto(model)
		end,
	},
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
		build = function(model: Model, _id: string, _detail: string?)
			buildSlugCarton(model)
		end,
	},
	[ShopData.ITEM.HAT_RED] = {
		view = SOLID_VIEW,
		build = function(model: Model, id: string, _detail: string?)
			buildHat(model, id)
		end,
	},
	-- THE TWO LICENCES ARE ONE BUILDER AND ONE ARGUMENT (task 228, spec 2.4): the same booklet in a
	-- different cloth, with a different animal on it.
	[ShopData.ITEM.BEATER_LICENCE] = {
		view = BOOK_VIEW,
		build = function(model: Model, _id: string, _detail: string?)
			buildLicence(model, "beater")
		end,
	},
	-- TASK 221: EVERY ROW THE SHOP SELLS HAS A PICTURE NOW (the Director, 2026-10-20). Six of the
	-- ten were drawing nothing, which is a declared fallback and still the wrong thing for a shop.
	[ShopData.ITEM.HIGH_SEAT] = {
		view = TALL_VIEW,
		build = function(model: Model, _id: string, _detail: string?)
			buildHighSeat(model)
		end,
	},
	[ShopData.ITEM.UNLIMITED_AMMO] = {
		view = SOLID_VIEW,
		build = function(model: Model, _id: string, detail: string?)
			buildBandolier(model, detail)
		end,
	},
	[ShopData.ITEM.RED_STAG] = {
		view = BOOK_VIEW,
		build = function(model: Model, _id: string, _detail: string?)
			buildLicence(model, "deer")
		end,
	},
	[ShopData.ITEM.ALWAYS_HUNTER] = {
		view = CARD_VIEW,
		build = function(model: Model, _id: string, _detail: string?)
			buildHunterPin(model)
		end,
	},
	-- THE PACKAGES DRAW THEIR OWN CONTENTS, through `ShopDisplay.build` per covered row -- so there
	-- is one drawing per item, a package can never show something it does not contain, and a row
	-- that gains a picture gains it inside every package that covers it.
	[ShopData.ITEM.BUNDLE_HIDE] = {
		view = SOLID_VIEW,
		build = function(model: Model, id: string, _detail: string?)
			buildBundle(model, id)
		end,
	},
	[ShopData.ITEM.BUNDLE_MARKSMAN] = {
		view = SOLID_VIEW,
		build = function(model: Model, id: string, _detail: string?)
			buildBundle(model, id)
		end,
	},
	[ShopData.ITEM.BUNDLE_SEASON] = {
		view = SOLID_VIEW,
		build = function(model: Model, id: string, _detail: string?)
			buildBundle(model, id)
		end,
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
--
-- `detail` IS THE ONE THING A CALLER MAY ASK FOR (task 228, spec 2.6): `"lite"` from `buildBundle`,
-- for the bandolier, whose 82 parts are six times the geometry for none of the picture inside a
-- 1.42-stud thumbnail. Every other caller passes nothing, and every other builder ignores it.
function ShopDisplay.build(id: string?, detail: string?): Model?
	local entry = if id ~= nil then DRAW[id] else nil
	if entry == nil then
		return nil
	end
	waiting = 0
	local model = Instance.new("Model")
	model.Name = string.format("ShopItem_%s", id :: string)
	entry.build(model, id :: string, detail)
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
