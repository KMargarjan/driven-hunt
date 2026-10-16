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
ShopDisplay.PAD = 1.15
-- SLOWLY. Karen asked for a picture that turns, and a turn you can read is a turn you do not notice:
-- 24 degrees a second is one revolution in fifteen seconds.
ShopDisplay.SPIN_DEG_PER_S = 24
ShopDisplay.LIGHT_DIRECTION = Vector3.new(-0.4, -1, -0.6)
ShopDisplay.LIGHT_COLOR = Color3.fromRGB(255, 248, 236)
ShopDisplay.AMBIENT = Color3.fromRGB(104, 108, 112)

-- WHERE THE CAMERA STANDS, in degrees around the item and degrees above it, per kind of thing: a
-- rifle is a SILHOUETTE and is photographed from its side, a hat and a box are photographed from
-- three-quarters on, a card is photographed nearly face-on or it is a line.
export type View = { yawDeg: number, pitchDeg: number, pad: number? }

local RIFLE_VIEW: View = { yawDeg = 96, pitchDeg = 16 }
local SOLID_VIEW: View = { yawDeg = 36, pitchDeg = 22 }
local CARD_VIEW: View = { yawDeg = 14, pitchDeg = 10, pad = 1.2 }

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
function ShopDisplay.spinDegAt(now: number): number
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

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	at: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Block
	part.Size = size
	part.CFrame = at
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	dress(part)
	part.Parent = parent
	return part
end

-- A CYLINDER'S AXIS IS ITS OWN X, which is the engine's rule and the one thing that is easy to get
-- wrong here: `Size.X` is the height and `Size.Y`/`Size.Z` are the diameter. Everything below stands
-- a cylinder UP by turning it 90 degrees about Z, once, in this function, so no call site repeats it.
local function upright(
	parent: Instance,
	name: string,
	height: number,
	diameter: number,
	at: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(height, diameter, diameter)
	part.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	dress(part)
	part.Parent = parent
	return part
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
local function buildRifle(parent: Model, sight: string?)
	local config = if sight ~= nil then { SIGHT = sight } else nil
	local folder = ReplicatedStorage:FindFirstChild(RifleGeometry.FOLDER_NAME)
	for _, piece in ipairs(RifleGeometry.pieces(config)) do
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

-- ---------------------------------------------------------------- the three things that are not guns

local CARDBOARD = Color3.fromRGB(176, 142, 100)
local HULL_RED = Color3.fromRGB(150, 32, 30)
local BRASS = Color3.fromRGB(196, 158, 78)
local CARD_CREAM = Color3.fromRGB(226, 220, 203)
local HUNTING_GREEN = Color3.fromRGB(42, 86, 48)
local INK = Color3.fromRGB(58, 54, 48)

-- A BOX OF SHELLS: the box, its label, and three cartridges standing out of it so the thing being
-- sold is visible and not just its packaging. Drawn out of parts rather than out of the uploaded
-- cartridge mesh on purpose -- that mesh is seated in the hand by `Gun.shellLayout`'s own numbers,
-- and a shop window that re-derived them would be the second reader of a seating this repo has
-- already paid to get right once.
local function buildShellBox(parent: Model)
	block(parent, "Box", Vector3.new(1.5, 0.78, 0.92), CFrame.new(0, 0, 0), CARDBOARD, Enum.Material.Fabric)
	block(parent, "Label", Vector3.new(1.08, 0.34, 0.02), CFrame.new(0, 0.06, 0.47), HULL_RED)
	block(parent, "LabelLine", Vector3.new(0.72, 0.06, 0.02), CFrame.new(0, -0.18, 0.47), INK)
	-- Three shells, leaning out of the open top: brass head down, red hull up.
	for index = 1, 3 do
		local x = -0.42 + (index - 1) * 0.42
		upright(parent, string.format("Hull%d", index), 0.62, 0.21, Vector3.new(x, 0.62, -0.1), HULL_RED)
		upright(
			parent,
			string.format("Head%d", index),
			0.2,
			0.22,
			Vector3.new(x, 0.21, -0.1),
			BRASS,
			Enum.Material.Metal
		)
	end
end

-- A CAP: a brim, a crown and a band. The COLOUR is the row's own `grants.hatColor` -- the thing being
-- bought is the colour, so a window that drew it in some other colour would be selling the wrong
-- item (see the header for why reading that one field here is not the panel deciding anything).
local function buildHat(parent: Model, id: string)
	local row = (ShopData.ROWS :: any)[id]
	local color = (row and row.grants and row.grants.hatColor) or Color3.fromRGB(150, 38, 32)
	upright(parent, "Brim", 0.1, 1.7, Vector3.new(0, 0, 0), color, Enum.Material.Fabric)
	upright(parent, "Crown", 0.52, 1.06, Vector3.new(0, 0.31, 0), color, Enum.Material.Fabric)
	upright(parent, "Band", 0.14, 1.12, Vector3.new(0, 0.12, 0), INK, Enum.Material.Fabric)
	-- The peak, forward over the brim, so a cap reads as a cap and not as a drum.
	block(parent, "Peak", Vector3.new(0.78, 0.07, 0.5), CFrame.new(0, 0.04, 0.78), color, Enum.Material.Fabric)
end

-- A LICENCE: a card with a green header, a photograph and two lines of writing. The lines are BLOCKS
-- and not text, and that is the engine's rule rather than a shortcut: a `SurfaceGui` does not render
-- inside a `ViewportFrame`, so writing on a card in a viewport is a thing that cannot be done.
local function buildLicence(parent: Model)
	block(parent, "Card", Vector3.new(1.62, 1.04, 0.05), CFrame.new(0, 0, 0), CARD_CREAM, Enum.Material.SmoothPlastic)
	block(parent, "Header", Vector3.new(1.62, 0.24, 0.055), CFrame.new(0, 0.4, 0), HUNTING_GREEN)
	block(parent, "Photo", Vector3.new(0.36, 0.44, 0.06), CFrame.new(-0.53, -0.12, 0.01), INK)
	for index = 1, 3 do
		block(
			parent,
			string.format("Line%d", index),
			Vector3.new(0.78, 0.07, 0.06),
			CFrame.new(0.14, 0.06 - (index - 1) * 0.18, 0.01),
			INK
		)
	end
end

-- ---------------------------------------------------------------- what to draw for an id

-- THE ONE TABLE THAT SAYS WHICH DRAWING AND WHICH CAMERA EACH ITEM GETS, keyed by the catalogue's own
-- ids. An id this table does not name draws NOTHING and the panel says so in words
-- (`Shop.CONFIG.TEXT.PICK`) rather than showing an empty rectangle -- the refusal `HeldTool.kindOf`
-- already makes for a Tool it does not name, and for the same reason: *"draw whatever is in the
-- hand"* is what once drew a shotgun out of a horn.
local DRAW: { [string]: { view: View, build: (Model, string) -> () } } = {
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
