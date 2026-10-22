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
--     own light direction and ambient colour. Mesh parts, colours and materials render, and so do
--     `Decal`s; Terrain, particles and `SurfaceGui` do NOT.
--
-- **TASK 241: THE PRINT IS ART NOW.** Karen, 2026-10-22: *"Slug shells has to be more releastic and
-- package smae with unlimited ammo / All things like beater license Deer license has to be clear and
-- nice"*. Every printed line in this file used to be a 3-px `Part`, because a `SurfaceGui` does not
-- render in a `ViewportFrame` -- but a `Decal` does. So the ammo keeps its real label on a real
-- carton, and the two licences leave the viewport altogether and become flat images over the case,
-- because a document has to be READ. The split, the geometry and the readability proofs are the
-- Designer's `goods-spec.md` (2026-10-22, `<runs-dir>/design/`), and section 3.5 of it is one
-- function here: `ShopDisplay.dressLicenceImage`.
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
-- **`CARD_VIEW` IS GONE (task 243)**, with the hunter's pin it was the last reader of: yaw 15,
-- pitch 9, pad 1.18, rocking 17 degrees in nine seconds. It framed the one flat THING left in the
-- viewport, and section 8.1 of `goods-spec.md` turns that thing into a flat IMAGE over the case --
-- so all three documents this shop sells are now `ImageLabel`s that do not move at all, and a view
-- nothing points at would be a number waiting to be believed. `View.rockDegrees` and
-- `ShopDisplay.spinDegAt`'s rock branch STAY: they are the contract a `DOC_VIEW` would come back
-- on (`goods-spec.md` section 4), and `shop_panel.spec` holds the arithmetic to it directly.
--
-- `TALL_VIEW` is for the high seat (task 228) -- the thing is 2.3 studs tall and about 1 wide, and
-- `SOLID_VIEW`'s 25 degrees of pitch would squash it into a deck seen from above, which is exactly
-- what `.screenshots/228-before-access-highseat.png` shows.
--
-- **`BOOK_VIEW` IS GONE (task 241)**, with the open-booklet licences it was written for: yaw 13,
-- pitch 14, pad 1.14, rocking 15 degrees in ten seconds. A licence is a flat image over the case
-- now and has no camera at all, so a view nothing points at would be a number waiting to be
-- believed. It is in `backups/2026-10-22_task-241_*` with the drawing it framed, and
-- `goods-spec.md` section 4 carries the `DOC_VIEW` that would replace it if the licences ever go
-- back into the viewport.
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

-- HOW MANY FETCHES THIS SESSION HAS ASKED FOR AND HOW MANY IT ASKED FOR A SECOND TIME, so "it
-- retries" is a number a probe can read rather than a sentence in a comment (task 244).
local fetchStats = { asks = 0, retries = 0, imageAsks = 0, imageRetries = 0, warms = 0 }

-- **A FAILED FIRST FETCH IS ASKED FOR AGAIN (task 244).** `asked[id]` used to be set once and never
-- cleared, so an id whose first `PreloadAsync` FAILED -- a dropped packet, a cold CDN, a client that
-- joined before the asset was replicated -- was never asked for again and the grey fallback stood
-- for the rest of the session. `Enum.AssetFetchStatus.Failure` and `.TimedOut` are terminal
-- answers, not slow ones, so the only way out of them is to ask once more.
--   Enum.AssetFetchStatus https://create.roblox.com/docs/reference/engine/enums/AssetFetchStatus
--
-- IT IS NOT A LOOP: `asked[id]` is cleared on the failure, and the next CALL -- a rebuild, which
-- `ShopPanel.step` runs at most a few times a second while the case is waiting -- asks again. A
-- fetch that keeps failing keeps the loading state up, which is the honest picture and is what
-- Karen asked for instead of *"all weapons looks like parts"*.
local function askFor(id: string, holder: Instance)
	asked[id] = true
	fetchStats.asks += 1
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ holder })
		end)
	end)
end

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
	-- THE TWO TERMINAL FAILURES RE-ARM THE ASK. `Loading` and `None` are still "wait": one is in
	-- flight and the other has not been asked for yet, and asking again for an id that is already
	-- downloading would be a second request for the same bytes.
	if status == Enum.AssetFetchStatus.Failure or status == Enum.AssetFetchStatus.TimedOut then
		if asked[id] then
			fetchStats.retries += 1
		end
		asked[id] = false
	end
	if not asked[id] then
		askFor(id, part)
	end
	return false
end

-- IS THE MODEL ON SCREEN WAITING FOR ANYTHING? The panel asks this after a build and draws the item
-- again when it goes back to zero, which is the same stale-and-rebuild path `Camera.Viewmodel` takes
-- when the server's folder appears late.
function ShopDisplay.rebuildWanted(): boolean
	return waiting > 0
end

-- HOW MANY PIECES OF THE SELECTED ITEM ARE STILL MISSING, which is the same question with a number
-- on it: `ShopPanel` draws a LOADING state instead of the fallback while this is not zero, and a
-- probe can read it (task 244).
function ShopDisplay.waitingCount(): number
	return waiting
end

-- THE FETCH COUNTERS, for the reason every `stats` table in this Hud exists: *"it retries"* has to
-- be a number rather than a sentence.
function ShopDisplay.fetchStats()
	return table.clone(fetchStats)
end

-- ---------------------------------------------------------------- ASK EARLY (task 244)
--
-- KAREN, 2026-10-22, with a screenshot of the lever rifle drawn as a grey slab: *"on first load all
-- weapons looks like parts fix it when it loads only show weapon not boxes"*.
--
-- WHY THE SHOP IS THE WORST PLACE IN THE GAME FOR THIS, and `meshReady`'s own header says it: a
-- player who has only ever carried the shotgun has NEVER ASKED for the lever's meshes, so their
-- status is `None` until something asks -- and until task 244 the first thing that asked was the
-- draw itself, one piece at a time, as she looked at it.
--
-- SO THE PANEL ASKS WHEN IT OPENS, for every gun in the case at once, and the case shows a quiet
-- LOADING state until they land. It costs one `PreloadAsync` per mesh per session and it is the
-- SAME door the draw uses -- `meshReady`, which is what records `asked`/`arrived` -- so there is no
-- second asking mechanism to disagree with the first.
--
-- IT IS SAFE TO CALL AT ANY TIME AND COSTS NOTHING AFTER THE FIRST: `arrived[id]` short-circuits
-- every piece that has landed, and a world whose folders have not replicated yet simply finds
-- nothing and is asked again on the next open.
ShopDisplay.WARM_GEOMETRIES = { LeverGeometry, SemiAutoGeometry, RifleGeometry }

function ShopDisplay.warm(): number
	local asks = 0
	for _, geometry in ipairs(ShopDisplay.WARM_GEOMETRIES) do
		local folder = ReplicatedStorage:FindFirstChild(geometry.FOLDER_NAME)
		if folder == nil then
			continue
		end
		for _, piece in ipairs(folder:GetChildren()) do
			if piece:IsA("MeshPart") and not meshReady(piece) then
				asks += 1
			end
		end
	end
	fetchStats.warms += 1
	return asks
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
	-- TASK 241: ONE `Decal` PER FACE, keyed by Roblox's OWN `NormalId` and not by a word of ours --
	-- so the `Back`-is-`+z` trap section 2.5 writes out is read straight off the key. This is how a
	-- line of real type gets into a `ViewportFrame` at all: a `SurfaceGui` does not render in one.
	decals: { [Enum.NormalId]: string }?,
}

-- ASK FOR AN IMAGE ONCE PER SESSION, AND NEVER AGAIN. An unloaded `Decal` draws NOTHING, which on a
-- carton is a blank green wall -- the same failure mode `meshReady` above exists for, in the one
-- form a texture has. `ContentProvider:PreloadAsync` yields, so it goes on its own thread; nothing
-- here waits for it, and the engine draws the image the moment it lands.
local askedImage: { [string]: boolean } = {}

-- ...AND A FAILED IMAGE IS ASKED FOR AGAIN TOO (task 244), which is `meshReady`'s fix in the one
-- form a texture has: `askedImage[image]` was set once and never cleared, so a `Decal` whose first
-- fetch failed drew NOTHING -- a blank green wall on a carton -- for the rest of the session. The
-- status is read before the ask, exactly as it is for a mesh, and only the two TERMINAL answers
-- re-arm it.
local function preloadImage(holder: Instance, image: string)
	if askedImage[image] then
		local ok, status = pcall(function()
			return ContentProvider:GetAssetFetchStatus(image)
		end)
		if not ok or (status ~= Enum.AssetFetchStatus.Failure and status ~= Enum.AssetFetchStatus.TimedOut) then
			return
		end
		fetchStats.imageRetries += 1
	end
	askedImage[image] = true
	fetchStats.imageAsks += 1
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ holder })
		end)
	end)
end

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
	if piece.decals ~= nil then
		for face, image in pairs(piece.decals :: { [Enum.NormalId]: string }) do
			local decal = Instance.new("Decal")
			decal.Name = string.format("%s%s", piece.name, face.Name)
			decal.Face = face
			decal.Texture = image
			decal.Parent = part
			preloadImage(decal, image)
		end
	end
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
-- The first six are task 196's and task 221's; `BURGUNDY` below them is the shop2 spec's
-- section 2.2 (the Designer, 2026-10-21, `<runs-dir>/design/shop2-spec.md`).
local CREAM = Color3.fromHex("EDE4CE")
local LODEN = Color3.fromHex("27452E")
local BRASS = Color3.fromHex("C8A258")
-- TASK 221's THREE: the weathered timber a high seat is built of (`HighSeats.COLORS`' own two, which
-- were chosen against the lodge's logs and looked at in the live place), and the hunters' orange,
-- which is `Style.LOOK.BLAZE` -- named here rather than required, because this module draws PARTS
-- and has never required the Hud's palette.
local TIMBER = Color3.fromHex("8A7A5E")
local TIMBER_DARK = Color3.fromHex("6B5E47")
local BLAZE = Color3.fromHex("E2641B")

-- TASK 228: the shop2 spec's section 2.2. **WHAT IS LEFT OF IT**, after task 241 replaced the two
-- booklet licences, the ten-round tray and the bandolier with the Designer's `goods-spec.md`, and
-- task 243 replaced the hunter's pin and the package's lid label with section 8: one cover cloth,
-- which dresses a package's strap and its lid panel. `INK`, `FIELD`, `LODEN_DARK` and `ENAMEL` went
-- with the pin and the two lid ink bars, and are in `backups/2026-10-22_task-243_*` with the
-- drawings they were mixed for -- as the twenty-one hexes of task 241 are in its own backup. The
-- ammunition's own colours are the Designer's, in section 2.5.
local BURGUNDY = Color3.fromHex("6E1F22") -- the deer licence's cover cloth

-- ---------------------------------------------------------------- 2.4 the goods' own printed art
--
-- THE ONE ENGINE FACT THIS WHOLE SECTION TURNS ON (the Designer's `goods-spec.md`, section 0):
--
--   > **A `Decal` / `Texture` renders inside a `ViewportFrame`. A `SurfaceGui` does not.**
--
-- That is a deliberate `ViewportFrame` limitation and not a bug
-- (https://devforum.roblox.com/t/hey-is-it-possible-to-put-a-surfacegui-inside-a-viewport-frame/1999193,
-- https://devforum.roblox.com/t/surface-guis-do-not-display-inside-a-viewport-frame/2097636), and
-- it is why everything printed in this file used to be a 3-px `Part`. KAREN, 2026-10-22:
-- *"Slug shells has to be more releastic and package smae with unlimited ammo / All things like
-- beater license Deer license has to be clear and nice"*. A bar is a bar at every size; a line of
-- real type resolves. So the print is ART now, and the split is principled:
--
--   * **things you HOLD** (the ammo) stay 3-D in the case, like the guns, and get their print from
--     `Decal`s -- same camera, same light, same spin;
--   * **things you are ISSUED** (the two licences) become FLAT IMAGES over the case. A document has
--     to be READ, and at a 356 x 200 case a `Decal` on a part pitched 25 degrees cannot carry
--     readable body type. `goods-spec.md` section 4 states the all-3-D alternative and refuses it.
--
-- EVERY ONE OF THE FOUR IS OUR OWN ART -- drawn from scratch, no traced mark, no maker's name, no
-- borrowed asset -- so there is no licence question on any of them. The sources are the `.svg` files
-- beside each `.png` in the Designer's folder. Karen's upload OK, 2026-10-22, covers exactly those
-- four files and nothing else; `assets/uploads.json` carries her words verbatim against each id.
--
-- **THE ID BELOW IS THE IMAGE'S AND NOT THE DECAL'S, AND THAT TRAP HAS ALREADY COST THIS REPO A
-- WHOLE ROUND.** An Open Cloud upload of a PNG creates a **Decal** (`AssetTypeId 13`) and the id it
-- returns is the DECAL's -- which neither an `ImageLabel` nor a `Decal.Texture` can draw.
-- `src/shared/Report/init.luau` records the measurement that found it (task 205: three labels on one
-- plate, every one `IsLoaded = false`, and the card had been drawing no animal at all). The route out
-- is the same one: on the SERVER, `InsertService:LoadAsset(decalId)` returns a model holding a
-- `Decal` whose `.Texture` is the image. Resolved in DEV on 2026-10-22, all five `AssetTypeId 13`:
--
--   108290190291718 -> 124539390037781   goods-slugbox-face.png     1024 x 716
--   116011941064732 -> 95181634568725    goods-slugbox-end.png       468 x 1024
--   104459454968931 -> 118221829977446   goods-licence-beater.png   1024 x 572, alpha
--   92868335129939  -> 118076983085725   goods-licence-deer.png     1024 x 572, alpha
--   111542606757761 -> 78477647971930    goods2-hunter-card.png     1024 x 572, alpha  (task 243)
--
-- The DECAL ids stay in `assets/uploads.json`, because that file records what was UPLOADED.
--
-- **THE ONE WORD A CALLER MAY SAY TO A BUILDER**, and since task 241 it has one meaning: *this is a
-- thumbnail inside a package*. `buildBundle` is its only sender. It was `"lite"` for the bandolier
-- alone -- 82 parts inside a 1.42-stud picture -- and the string stays what it always was so no
-- caller or spec has to learn a new one; what changed is that the question is now about the
-- CONTEXT and not about one item's cost.
local IN_PACKAGE = "lite"

local ART = {
	SLUGBOX_FACE = "rbxassetid://124539390037781",
	SLUGBOX_END = "rbxassetid://95181634568725",
	LICENCE_BEATER = "rbxassetid://118221829977446",
	LICENCE_DEER = "rbxassetid://118076983085725",
	-- TASK 243 (`goods-spec.md` section 8.1): `ALWAYS HUNTER` was an enamelled lapel pin with NO
	-- WORDS ON IT -- two blank cream slabs where the print should be -- and the one thing a standing
	-- has to tell you is WHICH standing. It is a standing hunter's card now, the same 1024 x 572 as
	-- the two licences, so section 3.5's one placement rule covers it with nothing added.
	HUNTER_CARD = "rbxassetid://78477647971930",
}

-- ---------------------------------------------------------------- the licence rule (spec 3.5)
--
-- KAREN, 2026-10-22: *"licenses keep clear as you have now everywhere aligned then we good"*. So the
-- placement is ONE FUNCTION and not a paragraph repeated per screen: every surface that ever shows a
-- licence image calls `ShopDisplay.dressLicenceImage` and inherits the whole of the Designer's
-- section 3.5 -- upright, `Fit`, opaque, centred -- with no second chance to disagree.
--
-- TODAY THERE IS EXACTLY ONE CALLER, AND THAT IS MEASURED RATHER THAN ASSUMED: the shop's display
-- case. `Hud.LicenceCard` (task 238's no-licence popup) is a title, a sentence and two buttons and
-- holds no image at all; the start card's licence row is a drawn GLYPH plus text plus a tag
-- (`Drive.CONFIG.START_CARD_SPECIES_GLYPH` / `START_CARD_LICENCE_TAG`), also with no image. So
-- "the same everywhere" is true of one place today, and will be true of the second one for free.
ShopDisplay.LICENCE = {
	-- THE ART IS 1024 x 572 (**1.79 : 1**), and a container that is not 1.79 : 1 must LETTERBOX --
	-- which is what `ScaleType.Fit` does and what `Stretch` and `Crop` do not.
	ASPECT = 1024 / 572,
	-- THE SHOP CASE'S OWN INSET, measured by the Designer against the 356 x 200 case: 326 x 182
	-- rendered. Another container keeps the inset PROPORTIONAL rather than copying these two.
	INSET_X = 11,
	INSET_Y = 9,
	-- **NEVER RENDER EITHER LICENCE BELOW THIS WIDE.** `goods-readable-*.png` is the proof at 326 px;
	-- at roughly 150 the title is the last thing still resolving and everything else has become
	-- texture. Below it, show the row's words and NO image -- a green or red smear that cannot be
	-- read is worse than a word.
	MIN_WIDTH_PX = 150,
}

-- EVERY PROPERTY OF SECTION 3.5, IN ONE PLACE. It writes the RULE and not the picture: the caller
-- still owns `Image`, `Visible` and where the label sits, because those are that screen's business.
--
-- `Rotation = 0` IS THE RULE AND NOT AN OMISSION. The tilt, the shadow and the paper edge are
-- PAINTED INTO the artwork; a second tilt on top makes the document read as a loose sticker, and two
-- different tilts on two screens is exactly the "not aligned" Karen called out. It overrides the
-- optional breath the Designer offered in sections 3.3 and 3.4.
--
-- `ImageTransparency = 0` IS ALSO THE RULE: full opacity even when the row is locked or
-- unaffordable. Dim the row, the price or the button around it -- a half-faded document just looks
-- like a rendering bug.
function ShopDisplay.dressLicenceImage(label: ImageLabel)
	label.Rotation = 0
	label.ScaleType = Enum.ScaleType.Fit
	label.ImageTransparency = 0
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	-- `Pixelated` SHREDS THE HAIRLINE RULES at every size below 400 px, and the whole point of this
	-- art is that its hairlines read as print.
	label.ResampleMode = Enum.ResamplerMode.Default
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
end

-- IS A CONTAINER THIS WIDE BIG ENOUGH TO SHOW A LICENCE AT ALL? PURE, so the rule above is drivable
-- with a number. A width of zero or one is "the engine has not drawn a frame yet" and NOT "too
-- small" -- the same distinction `Style.MIN_SENSIBLE_PX` already makes, and for the same reason: the
-- panel is built before anything has been rendered.
function ShopDisplay.licenceFits(widthPx: number): boolean
	return widthPx <= 1 or widthPx >= ShopDisplay.LICENCE.MIN_WIDTH_PX
end

-- ---------------------------------------------------------------- 2.5 the slug carton (spec 3.1)
--
-- REAL SLUG AMMUNITION COMES **FIVE TO A BOX, IN A SMALL CLOSED CARTON** (Brenneke K.O. and Classic
-- Magnum, Rottweil Extra Line -- the Designer's section 1). A ten-round open tray is a CRATE, and a
-- crate made of bricks is a toy. That tray, the lid lying flat behind it and its 66 parts are what
-- this replaces.
--
-- THE CARTON IS THE ESTATE'S OWN and carries no real brand, mark or trade dress: a loden-green box
-- with a cream label and the same hunting-horn roundel the beater's licence wears, so the shop reads
-- as ONE supplier rather than four unrelated props.
local CARTON_GREEN = Color3.fromHex("2F4231")
local SHIPPING_CARD = Color3.fromHex("A4874F") -- the slab the stack is shipped on
local RIM_BRASS = Color3.fromHex("8E6E2C")
local HEAD_BRASS = Color3.fromHex("B08C3E")
local HULL_RED = Color3.fromHex("9E3127")
local CRIMP_LIP = Color3.fromHex("9A3026")
local CRIMP_TOP = Color3.fromHex("C25240")
local PRIMER_NICKEL = Color3.fromHex("A7A194")

local CARTON_SIZE = Vector3.new(1.00, 0.70, 0.32)
local LID_BAND_SIZE = Vector3.new(0.92, 0.012, 0.19)
-- THE LID BAND'S OFFSET FROM THE CARTON'S CENTRE, which is the Designer's two rows read against each
-- other: 0.006 proud of the 0.70-high top, and 0.03 back from the front wall. Written as an OFFSET
-- rather than as a second absolute position, so moving a carton can never leave its band behind.
local LID_BAND_AT = Vector3.new(0, 0.356, -0.03)

-- **THE `Back`/`Front` TRAP, WHICH THIS FILE HAS ALREADY FALLEN INTO ONCE.** Roblox's
-- `Enum.NormalId.Front` is **-Z**. `SOLID_VIEW` stands the camera at yaw 34, so it looks from
-- `+x / +z` and the wall it sees is **+Z = `Back`**. The `buildAmmoCrate` of two tasks ago
-- stencilled `-z` and nobody ever saw it. The end the camera also catches is **+X = `Right`**.
--
-- **WHY `Decal` AND NOT `Texture`.** A `Decal` stretches to fill its whole face; a `Texture` tiles at
-- `StudsPerTileU/V`. One label filling one face is a `Decal`.
--
-- **AND WHY THE ART IS 1024 x 716 WHILE THE END IS 468 x 1024.** A `Decal` stretches to whatever face
-- it lands on, so THE ART'S ASPECT MUST BE THE FACE'S ASPECT or every letter is silently squeezed.
-- Front face `1.00 x 0.70` -> 1.43 : 1 -> 1024 x 716. End face `0.32 x 0.70` -> 0.457 : 1 ->
-- 468 x 1024. Change the carton's proportions and the art has to be re-cut.
local function carton(rows: { Piece }, prefix: string, centre: Vector3)
	rows[#rows + 1] = {
		name = prefix,
		size = CARTON_SIZE,
		at = centre,
		color = CARTON_GREEN,
		decals = {
			[Enum.NormalId.Back] = ART.SLUGBOX_FACE,
			[Enum.NormalId.Right] = ART.SLUGBOX_END,
		},
	}
	rows[#rows + 1] = {
		name = prefix .. "LidBand",
		size = LID_BAND_SIZE,
		at = centre + LID_BAND_AT,
		color = CREAM,
	}
end

-- ONE ROW OF THE ROUND, ALONG ITS OWN AXIS. `at` is measured from the HEAD FACE.
type Section = {
	name: string,
	length: number,
	diameter: number,
	at: number,
	color: Color3,
	material: Enum.Material?,
	reflectance: number?,
}

-- ONE ROUND = SIX COAXIAL CYLINDERS, and every number is real. Anchored on Karen's own *"about 70 mm
-- long, about 20 mm across"*: body and head 0.800-0.809 in = 20.4 mm, rim 0.886 in max = 22.5 mm
-- (SAAMI, as quoted on the cartridge-collectors forum), a 209 primer 6.2 mm, high brass 20 mm. One
-- stud = 112.9 mm falls out of 70 mm = 0.620 studs.
--
-- **THE CRIMP IS A ROLL CRIMP, NOT A STAR.** `RIFLED SLUG` on the box means a **Foster**, and
-- *"unlike the Foster slug which is traditionally roll-crimped, the wad slug is fold-crimped"*
-- (https://en.wikipedia.org/wiki/Shotgun_slug). Slug loads are roll-crimped so you can see at a
-- glance that they are slugs (https://gundigest.com/gear-ammo/ammunition/12-gauge-slugs). A roll
-- crimp is a FLAT CLOSED DISC SET JUST BELOW A ROLLED-OVER LIP; the six-petal star fold belongs on
-- birdshot and must not appear here.
--
-- **`CrimpTop` IS BRIGHTER THAN THE HULL (`C25240` against `9E3127`), AND THAT IS THE WHOLE FIX**
-- (Karen, 22 Oct: *"slugs itself looks odd"*). It is a flat disc facing straight up into a key light
-- that comes from above, so it is the brightest part of the round. Drawing it DARKER than the ring
-- around it is precisely how you draw the mouth of an open TUBE -- which is what she was looking at.
--
-- **THE PRIMER IS NOT A DETAIL, IT IS THE WHOLE WORD.** One small nickel circle on the head is the
-- difference between A CARTRIDGE and A LENGTH OF RED TUBE. Its `at` is NEGATIVE so that it stands
-- 0.004 proud of the rim face and never z-fights.
local ROUND: { Section } = {
	{
		name = "Rim",
		length = 0.013,
		diameter = 0.200,
		at = 0,
		color = RIM_BRASS,
		material = Enum.Material.Metal,
		reflectance = 0.18,
	},
	{
		name = "Head",
		length = 0.164,
		diameter = 0.181,
		at = 0.013,
		color = HEAD_BRASS,
		material = Enum.Material.Metal,
		reflectance = 0.22,
	},
	{ name = "Hull", length = 0.427, diameter = 0.181, at = 0.177, color = HULL_RED },
	{ name = "CrimpLip", length = 0.016, diameter = 0.181, at = 0.604, color = CRIMP_LIP },
	{ name = "CrimpTop", length = 0.010, diameter = 0.151, at = 0.616, color = CRIMP_TOP },
	{
		name = "Primer",
		length = 0.008,
		diameter = 0.055,
		at = -0.004,
		color = PRIMER_NICKEL,
		material = Enum.Material.Metal,
		reflectance = 0.25,
	},
}

-- WHICH WAY A ROUND POINTS, as a rotation `place` will build verbatim.
--
-- **A ROBLOX `Cylinder`'S AXIS IS ITS X AXIS**, so every `Size` above is `(length, diameter,
-- diameter)` and a round is aimed by ROTATING that X axis -- not by changing which component is
-- largest. Getting this backwards gives you six discs.
--
-- STANDING is `Rz(90)`, which takes the round's own X axis to world `+y`: rim and primer on the
-- shelf, roll crimp up, and you read the crimp from above.
--
-- **LYING IS YAW 186 AND NOT -16**, and the Designer measured both: at -16 the round's head pointed
-- AWAY and the camera saw a blank crimp; at 186 the head face is tilted toward the lens, so the rim,
-- the brass and the primer are the end you see. The round still lies nearly flat across the shelf,
-- so the silhouette keeps about 81 % of its length.
local STANDING = Vector3.new(0, 0, 90)
local LYING = Vector3.new(0, 186, 0)

-- ONE ROUND, FROM ITS HEAD FACE OUTWARD. The direction each section steps along is read off THE VERY
-- `CFrame` `place` will build from the same `rot` -- its `RightVector`, which IS the part's own X
-- axis -- so there is no second copy of the trigonometry here to disagree with the drawing.
local function shell(rows: { Piece }, prefix: string, headFace: Vector3, rot: Vector3)
	local axis = CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z)).RightVector
	for _, section in ipairs(ROUND) do
		rows[#rows + 1] = {
			name = prefix .. section.name,
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(section.length, section.diameter, section.diameter),
			at = headFace + axis * (section.at + section.length / 2),
			rot = rot,
			color = section.color,
			material = section.material,
			reflectance = section.reflectance,
		}
	end
end

-- ONE CLOSED FIVE-ROUND CARTON AND TWO LOOSE ROUNDS. **14 parts and 2 `Decal`s**, against the 66
-- parts of the tray this replaces: better-looking and well under a quarter of the cost.
local function buildSlugCarton(parent: Model)
	local rows: { Piece } = {}
	carton(rows, "Carton", Vector3.new(0.04, 0.35, -0.04))
	shell(rows, "ShellA", Vector3.new(-0.70, 0, 0.44), STANDING)
	shell(rows, "ShellB", Vector3.new(0.44, 0.0905, 0.60), LYING)
	pieces(parent, rows)
end

-- ---------------------------------------------------------------- 2.6 unlimited ammo (spec 3.2)
--
-- **KAREN'S INSTRUCTION, TAKEN LITERALLY**: *"package smae with unlimited ammo"*. The same carton,
-- the same label, the same two rounds -- just a lot of them. No new art and no new upload: it reuses
-- the two ids section 2.5 already has.
--
-- WHAT THIS REPLACES IS THE BANDOLIER, and the reason is her sentence and not taste: a ring of loops
-- shares no colour, no shape and no label with the slug carton beside it, which is the clearest
-- example in the shop of the "no family" fault she named.
--
-- **STACKED FACES-OUT, NOT STOOD ON END IN A CRATE.** The Designer built it both ways: stood on end
-- with their narrow panels showing, cartons read as BOOKS ON A SHELF; laid the way they are actually
-- stacked, every one shows the same label and the item says A LOT OF THIS EXACT AMMUNITION with no
-- caption. It is also literally the same part seven times.
--
-- THE `y` VALUES BELOW ARE EACH COURSE'S **BASE** and the `x` its CENTRE, which is how the Designer's
-- table reads against the carton's own 0.70 height: 0.12 is the top of the shipping slab, and 0.83 is
-- 0.12 + 0.70 plus a hair.
local STACK_X = { -1.52, -0.50, 0.52 }
local STACK_BASE_Y = { 0.12, 0.83 }
local STACK_Z = -0.26

-- ---------------- THE SAME STACK, PACKED (task 243, `goods-spec.md` section 8.2c)
--
-- THE SHIPPING STACK IS 3.9 STUDS WIDE AND NO PACKAGE CASE IS: the Designer's two cases are 3.30
-- and 4.60 outside, which is 3.14 and 4.44 of inner shelf, and `THE FULL SEASON` has to fit a tower,
-- a slug carton, a gun and two documents on the same shelf. So the stack has a PACKED arrangement,
-- and that is what `IN_PACKAGE` is for -- *am I a thumbnail* -- rather than the packager reaching
-- in and re-placing another row's cartons.
--
-- **IT IS THE SAME CARTON AT THE SAME SIZE**, which is the rule section 8.2b states and this is the
-- place it could most easily have been broken: three of the shipped seven, no shipping slab and no
-- loose rounds, two staggered on the floor and one across their joint. 2.02 studs wide and 1.40
-- high, so it fits BOTH cases and still stands well proud of the 0.22 rim.
--
-- WHY THREE AND NOT THE SHEET'S FIVE. Section 8.2c draws five in `THE MARKSMAN` and three in `THE
-- FULL SEASON`; five is 3.04 wide, and in the large case the back row would then be 3.04 + 1.34 of
-- slug + 0.68 of tower = 5.06 against 4.44 of shelf. One arrangement that fits both beats two that
-- need the packager to know how many cartons a package wants.
local PACKED_X = { -0.51, 0.51 }
local PACKED_TOP_X = 0
local PACKED_BASE_Y = { 0, 0.70 }

-- **BOTTOM COURSE BEFORE TOP, AND LEFT TO RIGHT INSIDE EACH COURSE** (the Designer's own note): at
-- yaw 34 the camera sees each carton's `+X` end, so a carton comes before the neighbour that covers
-- that end. **27 parts and 14 `Decal`s** in the case, 6 and 3 packed, all reusing two uploaded
-- images.
local function buildAmmoStack(parent: Model, detail: string?)
	if detail == IN_PACKAGE then
		local packed: { Piece } = {}
		for index, x in ipairs(PACKED_X) do
			carton(packed, string.format("Carton%d", index), Vector3.new(x, PACKED_BASE_Y[1] + CARTON_SIZE.Y / 2, 0))
		end
		carton(packed, "Carton3", Vector3.new(PACKED_TOP_X, PACKED_BASE_Y[2] + CARTON_SIZE.Y / 2, 0))
		pieces(parent, packed)
		return
	end
	local rows: { Piece } = {
		{
			name = "Flat",
			size = Vector3.new(3.20, 0.12, 0.80),
			at = Vector3.new(0, 0.06, 0.06),
			color = SHIPPING_CARD,
		},
	}
	local index = 0
	for _, baseY in ipairs(STACK_BASE_Y) do
		for _, x in ipairs(STACK_X) do
			index += 1
			carton(rows, string.format("Carton%d", index), Vector3.new(x, baseY + CARTON_SIZE.Y / 2, STACK_Z))
		end
	end
	-- THE SEVENTH, OFF THE STACK AND ON THE SHELF, so the item reads as a quantity and not a wall.
	carton(rows, "Carton7", Vector3.new(-0.55, CARTON_SIZE.Y / 2, 0.52))
	shell(rows, "ShellA", Vector3.new(1.26, 0, 0.42), STANDING)
	shell(rows, "ShellB", Vector3.new(0.62, 0.0905, 0.92), LYING)
	pieces(parent, rows)
end

-- ---------------------------------------------------------------- 2.7 a document INSIDE a package
--
-- ALL THREE DOCUMENTS THIS SHOP SELLS -- the beater licence, the deer licence and, since task 243,
-- the hunter's card -- are flat images over the case and have NO viewport model. But `THE FULL
-- SEASON` covers two of them, and a package draws `ShopDisplay.build` per covered row. Drawing
-- nothing there would leave a HOLE in a shipped surface, so this is the one place a document still
-- has geometry: a single thin card carrying the SAME uploaded image.
--
-- IT IS `goods-spec.md` SECTION 4's OWN SHAPE, which the Designer wrote out and then refused for the
-- display case -- *"even at pitch 62 the body type loses about half its height"*. That objection is
-- about READING the document, and inside a package the item is a thumbnail nobody reads: what it has
-- to say is *a document*, which a card with real print on it says and a blank rectangle does not.
-- Refused for the case, right for the thumbnail.
--
-- **IT LIES FLAT NOW, AND THAT IS SECTION 8.2b's `FLAT` SLOT** (task 243). Until this task it STOOD,
-- leaning back 18 degrees, because everything in a package stood at a uniform 1.42 studs and a
-- document lying among them read as one that had fallen over. Nothing stands at a uniform height
-- any more -- the case is fixed and each thing is fitted in by its SHAPE -- and the shape of a
-- document in a packed case is FLAT, at the front where the lid does not cover it. So the decal
-- moves from the `Back` face (`+z`, the wall the camera was on) to the **`Top`** face, which is the
-- one the camera on `+x / +z` at 25 degrees of pitch is now looking at.
--
-- **ITS PROPORTIONS ARE THE ART'S AND NOT A ROUNDED PAIR.** The image is 1024 x 572 (1.79 : 1) and a
-- `Decal` stretches to its face, so the depth is the width divided by that ratio -- the same rule
-- section 2.5 states for the carton's two faces, applied here. 1.04 across gives 0.581 deep, which
-- is section 8.2b's own `1.04 x 0.58` to the millimetre.
local LICENCE_CARD_WIDTH = 1.04
local LICENCE_CARD_SIZE = Vector3.new(LICENCE_CARD_WIDTH, 0.016, LICENCE_CARD_WIDTH / ShopDisplay.LICENCE.ASPECT)
local LICENCE_CARD_EDGE = Color3.fromHex("D8D2C2")

local function buildLicenceCard(parent: Model, image: string)
	pieces(parent, {
		{
			name = "Licence",
			size = LICENCE_CARD_SIZE,
			at = Vector3.new(0, LICENCE_CARD_SIZE.Y / 2, 0),
			color = LICENCE_CARD_EDGE,
			decals = { [Enum.NormalId.Top] = image },
		},
	})
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
	-- `LADDER_OVER_DECK_STUDS` past the deck: that part is exactly the real one's.
	--
	-- ITS PLANE IS THE TRUSS'S OUTER FACE AND NOT ITS CENTRE, and that is a LOOK decision, not the
	-- real seat's own number (Reviewer, round 1, and the note is right that the earlier comment
	-- claimed otherwise). The real truss is 2 studs deep, spanning -3 to -5; a picture of it is one
	-- plane, and the outer face is the one a climber's hands are on and the one the camera at yaw
	-- 30 is looking at. BOTH WERE SHOT AT THE SAME PARKED YAW before this was settled:
	-- `.screenshots/228-seat-outerface.png` stands the ladder clear of the near legs with the key
	-- tag readable on it, and at the centre plane it crosses them and the whole stand reads as a
	-- lattice of sticks.
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

-- ---------------------------------------------------------------- 2.9 the packages (spec 8.2)
--
-- KAREN, 2026-10-22, on the shipped build: *"package The hide has to be improved now is broke n /
-- package marksman also broken / the full season also broken"*.
--
-- **THE CASE IS A FIXED BOX AND THE GOODS ARE FITTED INTO IT; AND WHERE A THING GOES IS DECIDED BY
-- ITS SHAPE, WHICH THE CODE ALREADY KNOWS** (the Designer's `goods-spec.md` section 8.2). That one
-- sentence answers all three of her faults:
--
--   A. THE CASE USED TO GROW WITH THE CONTENTS and only the WINDOW was fixed -- `w = #drawable *
--      BUNDLE_SPREAD + 0.4` -- so six items made a 10.12-stud trough drawn at 34.7 px per stud
--      against 71.3 for a two-item package. The same shop drew its packages at half scale and
--      twice, and the season's was the half: a footbridge seen from above with six crumbs on it.
--   B. `BUNDLE_ITEM_STUDS` 1.42 MADE EVERY ITEM A CUBE whatever it really was. A scoped rifle is
--      about eight times as long as it is deep; squeezed into a 1.42-stud cell and laid flat in a
--      0.76-deep trough it became a dark stick on dark wood -- which is why the row whose blurb
--      says *"the long gun"* CONTAINED NO GUN YOU COULD FIND.
--   C. THE BRIGHTEST OBJECT IN ALL THREE PICTURES WAS A BLANK LABEL: `CaseLidLabel`, 0.78 x 0.38 of
--      cream carrying two ink bars, which is section 0's own fault on a third surface.
--
-- WHAT DOES NOT CHANGE IS THE RULE THAT MATTERS: a package still calls `ShopDisplay.build(covered)`
-- once per covered row, so it cannot show something it does not contain and a row that gains a
-- picture gains it inside every package that covers it. What changed is the STAGING.
--
-- **THE ONE PLACE THIS FILE DEPARTS FROM THE DESIGNER'S SHEET, AND WHY.** Section 8.2c stages each
-- package's sub-pieces by hand -- five cartons in `THE MARKSMAN`, three in `THE FULL SEASON`, the
-- slug's two loose rounds re-placed around its own box. A packager that did that would be writing a
-- second copy of another row's geometry, which is exactly the rule above. So the SLOT is this
-- module's and the ARRANGEMENT INSIDE A ROW is that row's: `buildAmmoStack` has one compact
-- in-package stack (section 8.2c's own three cartons, the count that fits BOTH cases), and it is
-- drawn in both packages. Everything else -- the two case sizes, the low rim, the slot per shape,
-- the chocks, the document step -- is the sheet's, to the decimal where the sheet gives one.
local CASE_SMALL = Vector2.new(3.30, 1.70) -- 2-3 items: THE HIDE, THE MARKSMAN
local CASE_LARGE = Vector2.new(4.60, 1.85) -- 4-6 items: THE FULL SEASON
local CASE_LARGE_FROM = 4

-- THE BOX ITSELF, in the case's own frame: y 0 is the bottom of the case and +z is the wall the
-- camera is on. The goods stand on `CASE_FLOOR_TOP`.
local CASE_WALL = 0.08
local CASE_FLOOR_TOP = 0.08
local CASE_LINING = 0.016 -- the cloth, which IS the top of the floor rather than a sheet laid on it
-- **THE RIM IS 0.22 AND THAT IS A MEASUREMENT, NOT A TASTE** (section 8.2a). At pitch 25 a wall of
-- height `t` hides everything below `t - dz * tan 25` for a thing `dz` studs behind it. At the old
-- 0.30 the front wall hid the rifle COMPLETELY -- 0.30 - 0.43 * 0.466 = 0.10, and a gun on the
-- lining tops out at 0.11. At 0.22 nothing in the case is hidden by its own box, and this file
-- MEASURES that rather than trusting it: the documents are laid at the z where the sight line from
-- their own top clears the front rim (`RIM_SIGHT` below).
local CASE_RIM_TOP = 0.22
local LID_DEG = 78
local LID_DEEP = 0.40
local LID_THICK = 0.055
-- THE LID IS A TIMBER FRAME WITH A CLOTH PANEL INSET, in the package's own strap colour -- and it
-- carries NO LABEL, NO INK BARS AND NO IMAGE (section 8.3). The widest a plate could be on the lid
-- is about 2.6 studs, which at 54.3 px per stud is 141 px on screen; `THE FULL SEASON` is fifteen
-- characters, so 9 px a letter -- and the panel already prints the same words at 29 px eleven
-- pixels under the case. A plate would say a thing worse, directly below where it is said well.
local LID_PANEL_INSET = 0.22

-- WHAT TELLS THE THREE APART IN THE PICTURE: what is in them, and the strap and lid colour -- loden,
-- burgundy, blaze, one each. That is the signature `buildBundle` already had, and Karen can read it
-- before a word.
local STRAP_COLOR: { [string]: Color3 } = {
	[ShopData.ITEM.BUNDLE_HIDE] = LODEN,
	[ShopData.ITEM.BUNDLE_MARKSMAN] = BURGUNDY,
	[ShopData.ITEM.BUNDLE_SEASON] = BLAZE,
}
-- THE HIDE'S LID CLOTH IS TWO STEPS LIGHTER THAN ITS LINING, or it vanishes into it: the lining is
-- `LODEN` and the lid is the Designer's `35603D`. The other two straps already read against loden.
local LID_PANEL_COLOR: { [string]: Color3 } = {
	[ShopData.ITEM.BUNDLE_HIDE] = Color3.fromHex("35603D"),
	[ShopData.ITEM.BUNDLE_MARKSMAN] = BURGUNDY,
	[ShopData.ITEM.BUNDLE_SEASON] = BLAZE,
}

-- ---------------- WHERE A THING GOES: a rule, not a table per package (section 8.2b)
--
-- EACH SLOT'S TEST USES SOMETHING THIS MODULE ALREADY HAS -- `imageFor`, `viewFor` and the model's
-- own extents -- so nothing here is a second opinion about what an item IS.
ShopDisplay.SLOT = {
	-- any document: it lies flat at the front, where the lid does not cover it
	FLAT = "flat",
	-- the high seat: it stands at the back, because nothing else in this shop is tall
	TALL = "tall",
	-- the scoped rifle: it lies on its left side on two chocks, across the front
	LONG = "long",
	-- the cartons and the stack: they stand on the floor along the back, at their own size
	SOLID = "solid",
}
-- HOW LONG / HOW TALL / HOW WIDE EACH FITTED SLOT IS, in studs. `SOLID` is absent on purpose: **the
-- cartons are NOT scaled.** A slug box is 1.00 x 0.70 x 0.32 (section 3.1) and it stays that in
-- every package, so the same object is the same size everywhere in the shop. `BUNDLE_ITEM_STUDS`
-- -- the 1.42-stud cell that made a rifle a cube -- is deleted.
ShopDisplay.SLOT_STUDS = {
	flat = 1.04, -- across; the depth follows the art's 1.79 : 1
	tall = 1.50, -- high
	long = 2.80, -- along the barrel
}

-- WHICH SLOT AN ITEM TAKES. PURE and exported, so `shop_panel.spec` can hold each shipped row to the
-- slot the Designer's sheet names instead of trusting this to stay true.
--
-- **THE LONG TEST IS ON THE LONGEST HORIZONTAL EXTENT AND NOT ON `x`**, which is the one line of
-- section 8.2b that had to be translated rather than copied: the sheet is drawn in the Designer's
-- own frame, and in THIS repository a gun is built along **z** (`Rifle.Geometry`'s `muzzleZ`, which
-- is why `RIFLE_VIEW` stands the camera at yaw 96 to photograph its side). Written against `x` the
-- rifle would have failed its own test and come out SOLID.
--
-- THE ORDER IS FLAT, TALL, LONG, SOLID, and it is not alphabetical: a document is 1.79 : 1 and
-- 0.016 thick, so the LONG test would claim it, and the high seat's ladder makes its base wide
-- enough that a future seat could trip the same test. The two tests that read an IDENTITY come
-- before the one that reads a shape.
function ShopDisplay.slotFor(id: string, size: Vector3): string
	if ShopDisplay.imageFor(id) ~= nil then
		return ShopDisplay.SLOT.FLAT
	end
	if ShopDisplay.viewFor(id) == TALL_VIEW then
		return ShopDisplay.SLOT.TALL
	end
	if math.max(size.X, size.Z) >= 2 * size.Y then
		return ShopDisplay.SLOT.LONG
	end
	return ShopDisplay.SLOT.SOLID
end

-- HOW MUCH TO SHRINK AN ITEM TO FIT ITS SLOT, or 1 for a `SOLID`. PURE. A zero extent answers 1
-- rather than dividing by it -- a model with no parts is `build`'s own nil case, not this one's.
function ShopDisplay.fitScale(slot: string, size: Vector3): number
	local want = (ShopDisplay.SLOT_STUDS :: any)[slot]
	if want == nil then
		return 1
	end
	local have = if slot == ShopDisplay.SLOT.TALL then size.Y else math.max(size.X, size.Z)
	if have <= 1e-4 then
		return 1
	end
	return math.clamp(want / have, 0.05, 4)
end

-- THE WORLD EXTENTS OF A BOX THAT HAS BEEN TURNED. PURE -- each world axis takes the absolute share
-- of each of the box's three sides -- and it is `halfExtents`' arithmetic over all three axes at
-- once. The rifle is the one caller: it is built along `z` and lands lying along `x`, so its height
-- and depth swap and a placer that read the UNTURNED box would stand it 0.6 studs into the lid.
function ShopDisplay.turnedSize(size: Vector3, rot: Vector3): Vector3
	local cf = CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	local right, up, look = cf.RightVector, cf.UpVector, cf.LookVector
	return Vector3.new(
		math.abs(right.X) * size.X + math.abs(up.X) * size.Y + math.abs(look.X) * size.Z,
		math.abs(right.Y) * size.X + math.abs(up.Y) * size.Y + math.abs(look.Y) * size.Z,
		math.abs(right.Z) * size.X + math.abs(up.Z) * size.Y + math.abs(look.Z) * size.Z
	)
end

-- **A GUN IN A CASE LIES ON ITS LEFT SIDE, AND THAT IS THE WHOLE DIFFERENCE.** From above you then
-- see the butt, the comb, the grip, the trigger guard, the action, the scope and the barrel -- the
-- shape that says RIFLE. Drawn in plan it is 0.065 of its length across and reads as a stick, which
-- is what the first cut of this picture came out as.
--
-- `(90, 90, 0)` IS `Rx(90) * Ry(90)` and it is TWO turns for two reasons. The yaw lays the barrel
-- (local `+z`) along the case's long axis `+x`; the roll takes the gun's own UP to `+z`, the wall
-- the camera is on, which puts its RIGHT side uppermost -- so it is lying on its LEFT, and the bolt
-- handle and the scope are the two things the camera sees first.
local LONG_TURN = Vector3.new(90, 90, 0)
-- WHERE THE GUN'S BELLY SITS: on two chocks, 0.055 above the floor, which is what a cased gun really
-- lies on and what lifts the barrel clear of the near rim.
local CHOCK_SIZE = Vector3.new(0.10, 0.055, 0.34)
local LONG_BOTTOM_Y = CASE_FLOOR_TOP + CHOCK_SIZE.Y
-- AT A TENTH AND FIVE SIXTHS OF ITS OWN LENGTH -- under the butt and under the fore-end, the
-- Designer's own x -1.27 and +0.76 against a butt at -1.55 and a 2.80-stud gun.
local CHOCK_ALONG = { 0.10, 0.825 }
-- HOW FAR THE GUN STANDS OFF THE FRONT WALL.
local LONG_FRONT_CLEAR = 0.20
-- HOW FAR A THING IN THE BACK ROW STANDS OFF THE BACK WALL.
local BACK_CLEAR = 0.04
-- THE DOCUMENTS OVERLAP ON PURPOSE -- the hunter's card lies across the corner of the beater
-- licence, 0.022 studs proud of it so they never z-fight -- and they step toward the front-right
-- corner, 0.40 across and 0.22 forward each.
local DOC_STEP = Vector3.new(0.40, 0.022, 0.22)
local DOC_EDGE = 0.04
-- THE SIGHT LINE OVER THE NEAR RIM, which is the one number that decides how far forward a FLAT
-- thing may be laid: a thing whose top is `y` at depth `z` is hidden by a rim of height `T` at the
-- inner wall `Zw` when `y + RIM_SIGHT * (Zw - z) < T`. A document is 0.016 thick, so it is the one
-- item in the case this can actually swallow -- which is why the Designer's own z of 0.53 is
-- MEASURED here instead of copied: at 0.53 the near two fifths of the card are behind the rim.
local RIM_SIGHT = math.tan(math.rad(SOLID_VIEW.pitchDeg))

-- THE MODEL'S WORLD-ALIGNED BOX, computed over its own parts. `Model:GetBoundingBox` returns a box
-- in the PRIMARY PART'S basis, and several of these models' first part is a rotated one (a round on
-- its side, a yawed scope) -- so that box is neither axis-aligned nor the one a shelf has to stand
-- the thing on. PURE.
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

-- PUT A MODEL'S BOX WHERE IT IS WANTED, turned about that box's own centre. Moved by its BOX and
-- never by its pivot: the pivot is whichever part happened to be made first, which for a leaning
-- round or a stack of cartons is neither the model's centre nor its foot.
local function placeByBox(model: Model, at: Vector3, rot: Vector3?)
	local centre = worldBox(model)
	local turn = rot or Vector3.zero
	model:PivotTo(
		CFrame.new(at)
			* CFrame.Angles(math.rad(turn.X), math.rad(turn.Y), math.rad(turn.Z))
			* CFrame.new(-centre)
			* model:GetPivot()
	)
end

type Fitted = { id: string, model: Model, slot: string, size: Vector3 }

local function buildBundle(parent: Model, id: string)
	local row = ShopData.anyRow(id)
	local covers = (row and row.covers) or {}
	local drawable: { string } = {}
	for _, covered in ipairs(covers) do
		if ShopDisplay.knows(covered) then
			table.insert(drawable, covered)
		end
	end

	-- ---------------- the case: a fixed box in two sizes (section 8.2a)
	local box = if #drawable >= CASE_LARGE_FROM then CASE_LARGE else CASE_SMALL
	local w, d = box.X, box.Y
	local wood = Enum.Material.Wood
	local planks = Enum.Material.WoodPlanks
	local metal = Enum.Material.Metal
	local strap = STRAP_COLOR[id] or LODEN
	local panel = LID_PANEL_COLOR[id] or LODEN

	-- THE LID IS HINGED AT THE BACK RIM AND LEANS AWAY FROM THE CAMERA, so the camera on `+x / +z`
	-- looks at its INSIDE. Hinge it at the front and you have built a door that hides the goods.
	--
	-- `rot = (78, 0, 0)` takes the lid's local `+y` -- its inner face's normal -- to
	-- `(0, cos 78, sin 78)`, which points up and TOWARD the camera, and its local `-z` to
	-- `(0, sin 78, -cos 78)`, which is the way it leans back from the hinge. The hinge is the back
	-- rim, `(y 0.22, z -d/2)`, and the lid's far edge therefore lands at y 0.611 -- which is the
	-- Designer's own number for both cases, because only the hinge's z differs.
	local rad = math.rad(LID_DEG)
	local up = Vector3.new(0, math.cos(rad), math.sin(rad))
	local lean = Vector3.new(0, math.sin(rad), -math.cos(rad))
	local hinge = Vector3.new(0, CASE_RIM_TOP, -d / 2)
	local lidAt = hinge + lean * (LID_DEEP / 2)
	local lidTurn = Vector3.new(LID_DEG, 0, 0)

	local floorTop = CASE_FLOOR_TOP - CASE_LINING
	local wallHigh = CASE_RIM_TOP - floorTop
	local wallY = floorTop + wallHigh / 2
	pieces(parent, {
		{
			name = "CaseFloor",
			size = Vector3.new(w, floorTop, d),
			at = Vector3.new(0, floorTop / 2, 0),
			color = TIMBER_DARK,
			material = planks,
		},
		-- THE LINING **IS** THE TOP OF THE FLOOR and not a sheet laid on it, so the goods stand at
		-- `CASE_FLOOR_TOP` exactly and nothing is 0.016 studs inside the cloth it stands on.
		--
		-- **IT IS `SmoothPlastic` AND NOT `Fabric`, AND THAT WAS PHOTOGRAPHED** (rule 5,
		-- `.screenshots/243-goods-marksman.png` before and after). `Fabric`'s own weave is a
		-- speckle, and at a 356 x 200 case the whole floor of the box came out as mottled dark
		-- STONE rather than cloth -- the biggest single area in the picture, under a gun this task
		-- exists to make findable. It is the same measurement `TRUCK.CAMO.BODY_MATERIAL` records
		-- (*"the shot came back with four BLACK trucks ... `Fabric`'s own weave is dark enough to
		-- swallow an olive at this scale"*) and task 228's own note on this file.
		--
		-- **AND THE STRAP AND THE LID PANEL WENT THE SAME WAY, IN THE SAME PAIR OF FRAMES.** The strap
		-- is named in this file as the package's ONE SIGNATURE -- the thing that tells the three apart
		-- before a word is read -- and in burgundy `Fabric` it came out MOTTLED PURPLE across the whole
		-- front rim. A signature that reads as noise is not a signature. So **nothing in this case is
		-- `Fabric` any more**: not the lining, not the strap, not the lid's cloth panel and not the
		-- chocks. The panel is still a cloth panel in a timber frame -- that is what the inset and the
		-- two colours say -- it is simply painted rather than woven, because at 356 x 200 the weave is
		-- not texture, it is dirt.
		{
			name = "CaseLining",
			size = Vector3.new(w - 2 * CASE_WALL, CASE_LINING, d - 2 * CASE_WALL),
			at = Vector3.new(0, floorTop + CASE_LINING / 2, 0),
			color = LODEN,
		},
		{
			name = "CaseNear",
			size = Vector3.new(w, wallHigh, CASE_WALL),
			at = Vector3.new(0, wallY, d / 2 - CASE_WALL / 2),
			color = TIMBER,
			material = wood,
		},
		{
			name = "CaseBack",
			size = Vector3.new(w, wallHigh, CASE_WALL),
			at = Vector3.new(0, wallY, -d / 2 + CASE_WALL / 2),
			color = TIMBER,
			material = wood,
		},
		{
			name = "CaseLeft",
			size = Vector3.new(CASE_WALL, wallHigh, d - 2 * CASE_WALL),
			at = Vector3.new(-w / 2 + CASE_WALL / 2, wallY, 0),
			color = TIMBER_DARK,
			material = wood,
		},
		{
			name = "CaseRight",
			size = Vector3.new(CASE_WALL, wallHigh, d - 2 * CASE_WALL),
			at = Vector3.new(w / 2 - CASE_WALL / 2, wallY, 0),
			color = TIMBER_DARK,
			material = wood,
		},
		{
			name = "CaseLid",
			size = Vector3.new(w, LID_THICK, LID_DEEP),
			at = lidAt,
			rot = lidTurn,
			color = TIMBER,
			material = wood,
		},
		-- FILLED EDGE TO EDGE WITH ONE HUE A LID READS AS A PAINTED WALL; the frame is what makes it
		-- a lid. So the panel is inset and the timber shows all round it, and it is `SmoothPlastic`
		-- like everything else in this case -- `CaseLining` above carries the frames that decided it.
		{
			name = "CaseLidPanel",
			size = Vector3.new(w - LID_PANEL_INSET, 0.014, LID_DEEP - LID_PANEL_INSET / 2),
			at = lidAt + up * (LID_THICK / 2 + 0.007),
			rot = lidTurn,
			color = panel,
		},
		-- THE STRAP IS ON THE `+z` WALL for the same reason the carton's print is: that is the wall
		-- the camera is on.
		{
			name = "Strap",
			size = Vector3.new(w + 0.06, 0.105, 0.03),
			at = Vector3.new(0, wallY, d / 2 + 0.015),
			color = strap,
		},
		{
			name = "Escutcheon",
			size = Vector3.new(0.14, 0.12, 0.022),
			at = Vector3.new(0, wallY, d / 2 + 0.036),
			color = BRASS,
			material = metal,
			reflectance = 0.22,
		},
		{
			name = "CornerLeft",
			size = Vector3.new(0.12, wallHigh + 0.014, 0.12),
			at = Vector3.new(-w / 2 + 0.05, wallY, d / 2 - 0.05),
			color = BRASS,
			material = metal,
			reflectance = 0.18,
		},
		{
			name = "CornerRight",
			size = Vector3.new(0.12, wallHigh + 0.014, 0.12),
			at = Vector3.new(w / 2 - 0.05, wallY, d / 2 - 0.05),
			color = BRASS,
			material = metal,
			reflectance = 0.18,
		},
	})

	-- ---------------- the goods, one `ShopDisplay.build` per covered row (section 8.2b)
	--
	-- EVERY COVERED ROW IS TOLD IT IS IN A PACKAGE, and `IN_PACKAGE` has the one meaning its name
	-- says: *am I a thumbnail*. A document draws its card there and nothing in the case; the ammo
	-- stack draws its compact three-carton course instead of the seven-carton shipping stack, which
	-- is 3.9 studs wide and does not fit any case this shop can draw.
	local backRow: { Fitted } = {}
	local docs: { Fitted } = {}
	local long: Fitted? = nil
	for index, covered in ipairs(drawable) do
		local model = ShopDisplay.build(covered, IN_PACKAGE)
		if model ~= nil then
			model.Name = string.format("Part%d", index)
			local _, raw = worldBox(model)
			local slot = ShopDisplay.slotFor(covered, raw)
			local scale = ShopDisplay.fitScale(slot, raw)
			if math.abs(scale - 1) > 1e-4 then
				model:ScaleTo(scale)
			end
			local _, fitted = worldBox(model)
			local item: Fitted = { id = covered, model = model, slot = slot, size = fitted }
			if slot == ShopDisplay.SLOT.FLAT then
				table.insert(docs, item)
			elseif slot == ShopDisplay.SLOT.LONG and long == nil then
				long = item
			else
				-- A SECOND LONG THING WOULD HAVE NO SECOND FRONT TO LIE ACROSS, so it stands in the
				-- back row with the cartons. No package covers two guns today; this is what happens
				-- if one ever does, said here rather than left to a nil.
				table.insert(backRow, item)
			end
			model.Parent = parent
		end
	end

	local innerLeft, innerRight = -w / 2 + CASE_WALL, w / 2 - CASE_WALL
	local innerBack, innerFront = -d / 2 + CASE_WALL, d / 2 - CASE_WALL

	-- THE BACK ROW, left to right in the CATALOGUE'S OWN ORDER, with the slack shared evenly: n
	-- things make n + 1 gaps, so the row is centred and the end gaps match the ones between. The
	-- Designer's sheet lands within 0.12 studs of this everywhere it gives a number.
	local total = 0
	for _, item in ipairs(backRow) do
		total += item.size.X
	end
	local gap = math.max(0, (innerRight - innerLeft - total) / (#backRow + 1))
	local cursor = innerLeft + gap
	for _, item in ipairs(backRow) do
		placeByBox(
			item.model,
			Vector3.new(
				cursor + item.size.X / 2,
				CASE_FLOOR_TOP + item.size.Y / 2,
				innerBack + BACK_CLEAR + item.size.Z / 2
			)
		)
		cursor += item.size.X + gap
	end

	-- THE DOCUMENTS, FROM THE FRONT-RIGHT CORNER BACKWARD. The LAST one is laid as far forward as it
	-- can be SEEN -- the sight line from its own top, over the near rim -- and the ones before it
	-- step back, lower and to the left, so each is visible by construction rather than by hope.
	local lastFront = innerFront
	if #docs > 0 then
		local topY = CASE_FLOOR_TOP + (#docs - 1) * DOC_STEP.Y + docs[#docs].size.Y
		lastFront = math.min(innerFront, innerFront - (CASE_RIM_TOP - topY) / RIM_SIGHT)
	end
	for order, item in ipairs(docs) do
		local behind = #docs - order
		placeByBox(
			item.model,
			Vector3.new(
				innerRight - DOC_EDGE - item.size.X / 2 - behind * DOC_STEP.X,
				CASE_FLOOR_TOP + (order - 1) * DOC_STEP.Y + item.size.Y / 2,
				lastFront - item.size.Z / 2 - behind * DOC_STEP.Z
			)
		)
	end

	-- THE GUN, ACROSS THE FRONT, CENTRED IN WHAT THE DOCUMENTS LEAVE. In `THE MARKSMAN` that is the
	-- whole inner width; in `THE FULL SEASON` it is everything west of the first document, which
	-- puts the butt at -2.14 against the Designer's -2.12.
	if long ~= nil then
		local item = long :: Fitted
		local turned = ShopDisplay.turnedSize(item.size, LONG_TURN)
		local room = innerRight
		if #docs > 0 then
			room = innerRight - DOC_EDGE - docs[1].size.X - (#docs - 1) * DOC_STEP.X
		end
		local centreX = (innerLeft + room) / 2
		local centreZ = innerFront - LONG_FRONT_CLEAR - turned.Z / 2
		placeByBox(item.model, Vector3.new(centreX, LONG_BOTTOM_Y + turned.Y / 2, centreZ), LONG_TURN)
		for index, along in ipairs(CHOCK_ALONG) do
			place(parent, {
				name = string.format("Chock%d", index),
				size = CHOCK_SIZE,
				at = Vector3.new(centreX - turned.X / 2 + along * turned.X, CASE_FLOOR_TOP + CHOCK_SIZE.Y / 2, centreZ),
				color = LODEN,
			})
		end
	end
end

-- ---------------------------------------------------------------- what to draw for an id

-- THE ONE TABLE THAT SAYS WHICH DRAWING AND WHICH CAMERA EACH ITEM GETS, keyed by the catalogue's own
-- ids. An id this table does not name draws NOTHING and the panel says so in words
-- (`Shop.CONFIG.TEXT.PICK`) rather than showing an empty rectangle -- the refusal `HeldTool.kindOf`
-- already makes for a Tool it does not name, and for the same reason: *"draw whatever is in the
-- hand"* is what once drew a shotgun out of a horn.
--
-- **AN ITEM HAS A VIEWPORT MODEL OR AN IMAGE, NEVER BOTH** (task 241, `goods-spec.md` section 7
-- step 4). A thing you HOLD is a model under the case's camera; a thing you are ISSUED is a flat
-- image over the case, because a document has to be read and 25 degrees of pitch is a document you
-- cannot. `knows` is still the one question the panel and a package ask -- both kinds answer it.
type Drawing = {
	view: View,
	build: (Model, string, string?) -> (),
	-- A LICENCE'S OWN ARTWORK. Set only for the two licences, and `ShopPanel` is its one reader.
	image: string?,
}
local DRAW: { [string]: Drawing } = {
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
	-- THE TWO LICENCES ARE FLAT IMAGES OVER THE CASE (task 241, `goods-spec.md` sections 3.3 and
	-- 3.4), so their `build` draws NOTHING in the case and the `ViewportFrame` is left empty. The
	-- one place they still have geometry is INSIDE A PACKAGE, where a hole would be worse than a
	-- thumbnail (section 2.7 above) -- and `"lite"` is the one word that says so.
	--
	-- `view` IS NEVER READ FOR THESE TWO while they are the selected item (there is no model to
	-- aim at, and `ShopPanel.aim` returns early), and inside a package it is the PACKAGE's view
	-- that frames the board. It stays `SOLID_VIEW` so `viewFor` has an honest answer for every id
	-- rather than a special case.
	[ShopData.ITEM.BEATER_LICENCE] = {
		view = SOLID_VIEW,
		image = ART.LICENCE_BEATER,
		build = function(model: Model, _id: string, detail: string?)
			if detail == IN_PACKAGE then
				buildLicenceCard(model, ART.LICENCE_BEATER)
			end
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
			buildAmmoStack(model, detail)
		end,
	},
	[ShopData.ITEM.RED_STAG] = {
		view = SOLID_VIEW,
		image = ART.LICENCE_DEER,
		build = function(model: Model, _id: string, detail: string?)
			if detail == IN_PACKAGE then
				buildLicenceCard(model, ART.LICENCE_DEER)
			end
		end,
	},
	-- **TASK 243: THE THIRD DOCUMENT** (`goods-spec.md` section 8.1). KAREN, 2026-10-22: *"always
	-- hunter card has to be replaced into nice design like you did with deer license"*. It was an
	-- enamelled lapel pin -- 25 parts, a brass stag on a green ellipsoid, and TWO BLANK CREAM SLABS
	-- where the print should be, which is section 0's fault exactly: *"a bar is a bar at every size;
	-- a line of real type resolves"*. The one thing a standing has to tell you is WHICH standing,
	-- and a badge could not say it. It is a standing hunter's card now, drawn like the two licences
	-- and shown like them -- so `ShopDisplay.dressLicenceImage` needed no edit at all and the row
	-- inherits upright, `Fit`, opaque, centred for free. Twenty-five parts out, one `ImageLabel` in.
	[ShopData.ITEM.ALWAYS_HUNTER] = {
		view = SOLID_VIEW,
		image = ART.HUNTER_CARD,
		build = function(model: Model, _id: string, detail: string?)
			if detail == IN_PACKAGE then
				buildLicenceCard(model, ART.HUNTER_CARD)
			end
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

-- THE FLAT ARTWORK FOR ONE ITEM, or nil if this item is drawn as a model instead (task 241). It is
-- the OTHER half of `build`, and exactly one of the two answers for any id: a thing you HOLD has a
-- model, a thing you are ISSUED has an image. `ShopPanel` is the only caller, and it reads this
-- before it builds a picture.
function ShopDisplay.imageFor(id: string?): string?
	local entry = if id ~= nil then DRAW[id] else nil
	return if entry then entry.image else nil
end

-- THE MODEL FOR ONE ITEM, parentless, at the origin. nil for an id this module does not draw AND
-- for an id whose drawing is an IMAGE and not a model -- the two licences in the display case. A
-- caller that wants to know which is which asks `imageFor` as well, and the panel does.
--
-- `detail` IS THE ONE THING A CALLER MAY ASK FOR: `IN_PACKAGE` from `buildBundle`, meaning *this is
-- a 1.42-stud thumbnail inside a package*. Every other caller passes nothing. Today one builder
-- reads it -- a licence, which draws its card there and nothing in the case.
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
