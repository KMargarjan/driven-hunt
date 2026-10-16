--!strict
-- Hud.ShopPanel: THE ONE WRITER of everything inside the `ShopPanel` frame -- **including its
-- `Visible` and, since task 196, its SIZE** -- the one listener of the shopkeeper's `ProximityPrompt`,
-- and this client's one door onto `ReplicatedStorage.Shop.Remotes` (CLAUDE.md rule 3).
--
-- KAREN, 2026-10-13: *"Hunting house where inside can shop things"*; 2026-10-14: *"in lobby has to
-- be a person bot who you need to click E to get access to shop"*. So: walk up to the man behind the
-- counter, press E at him, and this opens; walk away and it closes.
--
-- KAREN, 2026-10-15 ~17:40, AND THIS TASK: *"menus for buying things has to be better more nicer
-- like side menu with click and then shows in right side image and explanation what is that"*.
--
-- SO THE PANEL IS TWO COLUMNS NOW, WHICH IS THE OLDEST LAYOUT IN SOFTWARE:
--   MASTER-DETAIL / split view -- a list of things on one side, the selected thing's own page on the
--   other. Apple's own description of it is the one this follows:
--   https://developer.apple.com/design/human-interface-guidelines/split-views
--     *"a primary column for a list of items and a secondary column for the selected item's
--     details"*, and its rule for small screens: keep ONE selection, never two.
--   The engine parts are Roblox's own, and each is cited where it is built:
--     ScrollingFrame  https://create.roblox.com/docs/reference/engine/classes/ScrollingFrame
--     UIListLayout    https://create.roblox.com/docs/reference/engine/classes/UIListLayout
--     ViewportFrame   https://create.roblox.com/docs/reference/engine/classes/ViewportFrame
--
-- WHAT REPLACED WHAT. Task 178 drew five rows, each with its own BUY button, in a fixed 360 x 320
-- rectangle: a price list. There was no room in it for a picture or for a sentence saying what a
-- slug IS, and Karen's complaint is exactly that. The rows are now a SIDE MENU (name, price, badge,
-- under a category header), and the right-hand column is the selected item's own page: a turning
-- picture of the real model (`Hud.ShopDisplay`), its name, its explanation, its price, its unlock
-- rule, and ONE big button. Five buttons became one, which is also five fewer ways to spend money by
-- accident.
--
-- SINCE TASK 181 THERE IS EXACTLY ONE WAY IN, AND IT IS THE PROMPT. Task 178 opened this panel by
-- itself when the player came within reach of the counter, and bound `E` through
-- `ContextActionService` to toggle it. BOTH ARE GONE: the auto-open made Karen's key decorative, and
-- a `Sink`ing `E` binding within 14 studs of the counter would have swallowed the prompt's own `E`
-- -- two owners of one key, which is the failure CLAUDE.md rule 3 exists for. What `near` still does
-- is CLOSE: walking away from the counter shuts the panel, at exactly the distance the server
-- refuses a purchase at.
--
--   ProximityPrompt  https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt
--     `Triggered` fires on the client that triggered it as well as on the server, so the panel
--     opens with no round trip -- and the purchase behind it is still the server's alone.
--
-- HOW YOU GET OUT, and one of the three is an engine fact rather than a choice: the `X` in the
-- corner, and walking away from the counter. **`Escape` IS NOT BINDABLE** -- it belongs to the Roblox
-- menu (`ReportPanel.bind`'s own note), so a panel that claimed to close on Escape would be lying.
-- That is reported rather than papered over, and it is why the `X` is a 48 px square where every
-- player already looks for it.
--
-- THE FRAME IS NOT ITS OWN. `Hud.build` creates it with the rest of the screen -- one ScreenGui,
-- built once, so a visibility audit has one place to look -- and this module fills it, sizes it and
-- owns its `Visible`.
--
-- IT DRAWS WHAT ARRIVED AND DECIDES NOTHING. Every word, every price, every badge and the `buyable`
-- of every row is computed ONCE, on the server, by the pure `Shop.rowsFor`, and arrives as a
-- `WireRow` -- the category and the explanation included, since task 196. The rule `ReportPanel`
-- already states (*"IT DRAWS WHAT ARRIVED AND COMPUTES NOTHING ... so two clients can never
-- disagree"*), and here it is also the security of the thing: a client that could decide it owned
-- something would be a client that could grant itself a rifle.
--
-- THE SELECTION IS AN ITEM ID AND NEVER AN INDEX, AND THAT IS NOT A STYLE CHOICE. Everything the
-- right-hand column says is read out of the CURRENT payload at RENDER time, by id, so a balance that
-- changes while the panel is open (a drive paying out, a purchase completing) redraws the button and
-- the badges with it. An index into a list, or a state copied into the pane when the row was
-- clicked, is how a greyed-out button and an accepted purchase come to disagree -- and this panel's
-- one job is that they never do.
--
-- IT HOLDS FIVE PIECES OF STATE AND IS THE ONLY WRITER OF ALL FIVE: `open`, `payload`, `message`,
-- `near`, `selected`.
--
-- IT OWNS THE CLIENT SIDE OF THE REMOTE, which is the one thing `ReportPanel` does not (that panel
-- reads `PlayerScripts.Report`, a replica the Hud's kill feed shares). Nothing else on this client
-- wants the shop's wire, and the Hud already owns a remote connection of its own for exactly that
-- reason (`Hud.onHitMarker` on `Shotgun.Remotes.HitMarker`).
--
--   TextButton           https://create.roblox.com/docs/reference/engine/classes/TextButton
--   GuiButton.Activated  https://create.roblox.com/docs/reference/engine/classes/GuiButton#Activated
--     one event for a click AND a tap, which is why this panel needs no touch branch at all
--     (`Hud.Rail`'s own citation).
--
-- Design: docs/design/shop.md (section 5)
-- Note:   docs/research/2026-10-14-the-shop.md, docs/research/2026-10-15-shop-window.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Drive = require(ReplicatedStorage:WaitForChild("Drive"))
local ShopData = require(ReplicatedStorage:WaitForChild("Shop"))
local ShopDisplay = require(script.Parent.ShopDisplay)

local ShopPanel = {}

local CONFIG = ShopData.CONFIG
local PANEL = CONFIG.PANEL
local TEXT = CONFIG.TEXT

-- THIS MODULE BINDS NO KEY AT ALL SINCE TASK 181, and `E` belongs to the shopkeeper's prompt
-- (`Lobby.CONFIG.LODGE.KEEPER.PROMPT.KEYBOARD_KEY`), which is the one owner of it. A grep for
-- "DrivenHunt.Shop." finds nothing here on purpose.

-- ---------------------------------------------------------------- the pixels this module owns
--
-- Every number here is a PIXEL, and pixels are the panel's only arithmetic. Everything that both
-- sides read -- the widths, the row height, the Z -- comes from `Shop.CONFIG.PANEL`; these are the
-- ones nothing outside this file needs.
local PAD = 12
local TITLE_SIZE = 18
local TEXT_SIZE = 14
local SMALL_SIZE = 12
local NAME_SIZE = 20
local Z = PANEL.Z_INDEX

ShopPanel.LOOK = {
	-- The report panel's own colour and its opacity, for the same MEASURED reason: the first frame of
	-- that panel was taken over a sunlit forest and the trees read straight through the text
	-- (`Report.CONFIG.PANEL_TRANSPARENCY`'s comment). A shop is a thing you stop and read.
	PANEL_COLOR = Color3.fromRGB(26, 29, 32),
	-- The two columns, a shade apart from the panel so the split reads without a border.
	COLUMN_COLOR = Color3.fromRGB(21, 23, 26),
	ROW_COLOR = Color3.fromRGB(40, 43, 46),
	-- THE SELECTED ROW. Hunting green, dark, so the selection is obvious without competing with the
	-- BUY button -- which is the same green at full strength.
	ROW_SELECTED_COLOR = Color3.fromRGB(34, 58, 38),
	BUY_COLOR = Color3.fromRGB(42, 86, 48), -- hunting green: the button you may press
	DEAD_COLOR = Color3.fromRGB(46, 48, 50), -- the button you may not
	RIM_COLOR = Color3.fromRGB(230, 230, 230),
	COIN_COLOR = Color3.fromRGB(255, 232, 150), -- the cream the board highlights your own row with
	OWNED_COLOR = Color3.fromRGB(150, 206, 158), -- a thing you already have
	LOCKED_COLOR = Color3.fromRGB(190, 160, 110), -- a thing the ladder is holding back
	HEADER_COLOR = Color3.fromRGB(150, 156, 160), -- a shelf's label
	IMAGE_COLOR = Color3.fromRGB(15, 17, 19), -- behind the picture
	-- How long a refusal stays on screen. The Hud's feed lines live 6 s; a line you caused by
	-- pressing a button needs less.
	MESSAGE_SECONDS = 4,
}

-- ---------------------------------------------------------------- state (five values, one writer)
local open = false
local near = false
local payload: any = nil
local message: string? = nil
local messageAt = -math.huge
local selected: string? = nil

local started = false
local prompt: any = nil
local promptConnection: any = nil
local panel: Frame? = nil
local title: TextLabel? = nil
local balance: TextLabel? = nil
local footer: TextLabel? = nil
local list: ScrollingFrame? = nil
local detail: Frame? = nil
local viewport: ViewportFrame? = nil
local viewportCamera: Camera? = nil
local viewportModel: Model? = nil
local viewportId: string? = nil
local viewportBuiltAt = -math.huge
-- THE BALL THE CAMERA HOLDS, measured ONCE per picture rather than once per frame: `GetExtentsSize`
-- walks every part, and the model does not change size while it turns.
local pictureCentre = Vector3.zero
local pictureRadius = 1
local screenWas = Vector2.zero
local menu: { { id: string, row: TextButton } } = {}
local headers: { TextLabel } = {}
local nameLabel: TextLabel? = nil
local priceLabel: TextLabel? = nil
local unlockLabel: TextLabel? = nil
local blurbLabel: TextLabel? = nil
local buyButton: TextButton? = nil
local remotes: any = nil
local Cursor: any = nil
local WeaponInput: any = nil
local enabled = true

local stats = {
	opens = 0,
	closes = 0,
	asks = 0,
	presses = 0,
	sent = 0,
	states = 0,
	renders = 0,
	prompts = 0,
	triggers = 0,
	selects = 0,
	pictures = 0,
	layouts = 0,
}

function ShopPanel.stats()
	return table.clone(stats)
end

function ShopPanel.isOpen(): boolean
	return open
end

function ShopPanel.isNear(): boolean
	return near
end

function ShopPanel.frame(): Frame?
	return panel
end

function ShopPanel.titleText(): string
	return if title then title.Text else ""
end

function ShopPanel.balanceText(): string
	return if balance then balance.Text else ""
end

function ShopPanel.messageText(): string
	return if footer then footer.Text else ""
end

function ShopPanel.lastState(): any
	return payload
end

function ShopPanel.selectedId(): string?
	return selected
end

-- WHAT IS ACTUALLY ON SCREEN IN THE SIDE MENU, row by row -- `ReportPanel.rowText`'s rule: the seam
-- a client spec reads instead of guessing. Task 159's lesson in one function (*"the panel reads, the
-- words do not"*). Each line is `NAME|PRICE AND BADGE`, which is the two lines of one row.
function ShopPanel.rowText(): { string }
	local out = {}
	for _, entry in ipairs(menu) do
		if entry.row.Visible then
			local name = entry.row:FindFirstChild("Name")
			local meta = entry.row:FindFirstChild("Meta")
			table.insert(
				out,
				string.format(
					"%s|%s",
					if name and name:IsA("TextLabel") then name.Text else "",
					if meta and meta:IsA("TextLabel") then meta.Text else ""
				)
			)
		end
	end
	return out
end

-- THE SHELF LABELS ON SCREEN, in order, for the same reason.
function ShopPanel.headerText(): { string }
	local out = {}
	for _, header in ipairs(headers) do
		if header.Visible then
			table.insert(out, header.Text)
		end
	end
	return out
end

-- WHAT THE RIGHT-HAND COLUMN SAYS, as five strings. One seam for the whole detail pane, so a spec
-- reads the screen rather than the payload it just handed in.
function ShopPanel.detailText(): { name: string, price: string, unlock: string, blurb: string, button: string }
	return {
		name = if nameLabel then nameLabel.Text else "",
		price = if priceLabel then priceLabel.Text else "",
		unlock = if unlockLabel then unlockLabel.Text else "",
		blurb = if blurbLabel then blurbLabel.Text else "",
		button = if buyButton then buyButton.Text else "",
	}
end

-- WHICH ITEM'S MODEL IS IN THE PICTURE RIGHT NOW, and the model itself. Two seams rather than one,
-- because *"a visibility audit certified a blank screen twice"* (docs/PROJECT_CONTEXT.md): a spec
-- that only read the id would believe a viewport holding nothing.
function ShopPanel.pictureId(): string?
	return viewportId
end

function ShopPanel.pictureModel(): Model?
	return viewportModel
end

function ShopPanel.viewportFrame(): ViewportFrame?
	return viewport
end

-- THE BALL THE PICTURE'S CAMERA IS AIMED AT: the model's own bounding centre and radius, measured
-- once when the picture was built. Exported because the camera is aimed AT THE BOX CENTRE and not at
-- the model's pivot (`Model:GetPivot` is its PrimaryPart's frame), so a spec checking where the lens
-- points has to be told which point to check against.
function ShopPanel.pictureBall(): (Vector3, number)
	return pictureCentre, pictureRadius
end

-- ---------------------------------------------------------------- the rectangle, pure
--
-- THE WHOLE LAYOUT AS ARITHMETIC (task 165's rule: *"asserted ARITHMETICALLY rather than by a
-- screenshot"*). PURE: a screen size in, every rectangle out, nothing read and nothing written. It is
-- what `Hud.build` sizes the frame with, what `relayout` writes, and what the client spec drives at
-- 400 x 800 and at 1920 x 1080 -- so "it fits a phone" is a test and not a hope.
export type Layout = {
	width: number,
	height: number,
	listX: number,
	listY: number,
	listWidth: number,
	listHeight: number,
	detailX: number,
	detailWidth: number,
	imageHeight: number,
	nameY: number,
	priceY: number,
	unlockY: number,
	blurbY: number,
	blurbHeight: number,
	blurbLines: number,
	buyY: number,
	buyHeight: number,
	rowHeight: number,
	headerHeight: number,
	gap: number,
}

function ShopPanel.layoutFor(screenWidth: number, screenHeight: number): Layout
	local margin = PANEL.MARGIN
	local width = math.clamp(screenWidth - 2 * margin, 240, PANEL.MAX_WIDTH)
	local height = math.clamp(screenHeight - 2 * margin, PANEL.MIN_HEIGHT, PANEL.MAX_HEIGHT)
	local bodyY = PANEL.HEADER_PX
	local bodyHeight = math.max(height - PANEL.HEADER_PX - PANEL.FOOTER_PX - PAD, 120)
	local bodyWidth = width - 2 * PAD
	-- THE LIST TAKES ITS FRACTION AND THEN ITS BOUNDS, in that order, so a narrow screen gives the
	-- list its minimum and the picture whatever is left rather than the other way round.
	local listWidth = math.floor(math.clamp(bodyWidth * PANEL.LIST_FRACTION, PANEL.LIST_MIN, PANEL.LIST_MAX))
	local detailX = PAD + listWidth + PAD
	local detailWidth = width - PAD - detailX
	-- THE PICTURE IS BOUNDED BY THE COLUMN'S HEIGHT AS WELL AS ITS WIDTH, and the measurement is in
	-- `PANEL.IMAGE_MAX_FRACTION`'s comment: without that cap, a 1920 px screen left TEN PIXELS for
	-- the explanation Karen asked for.
	local imageHeight = math.floor(
		math.clamp(
			math.min(detailWidth * PANEL.IMAGE_FRACTION, bodyHeight * PANEL.IMAGE_MAX_FRACTION),
			PANEL.IMAGE_MIN,
			PANEL.IMAGE_MAX
		)
	)
	-- THE DETAIL PANE'S FIVE ROWS, STACKED IN ONE PLACE. Each Y is the one above it plus that line's
	-- own height, so there is one arithmetic and `relayout` writes it rather than repeating it.
	local buyY = bodyHeight - PANEL.BUY_PX
	local nameY = imageHeight + 8
	local priceY = nameY + NAME_SIZE + 10
	local unlockY = priceY + TEXT_SIZE + 8
	local blurbY = unlockY + SMALL_SIZE + 14
	local lineHeight = SMALL_SIZE + 6
	-- WHATEVER IS LEFT between the unlock line and the button, and never less than one line: a
	-- paragraph given a negative height is a paragraph nobody reads.
	local blurbHeight = math.max(buyY - blurbY - 10, lineHeight)
	return {
		width = width,
		height = height,
		listX = PAD,
		listY = bodyY,
		listWidth = listWidth,
		listHeight = bodyHeight,
		detailX = detailX,
		detailWidth = detailWidth,
		imageHeight = imageHeight,
		nameY = nameY,
		priceY = priceY,
		unlockY = unlockY,
		blurbY = blurbY,
		blurbHeight = blurbHeight,
		-- HOW MANY LINES OF THE EXPLANATION ACTUALLY FIT, which is the number
		-- `Shop.CONFIG.PANEL.BLURB_MAX` was measured against -- and the client spec asserts that the
		-- PHONE case still holds a whole `BLURB_MAX` of text. A layout change that quietly starts
		-- clipping Karen's sentences fails the harness instead of looking fine on a monitor.
		blurbLines = math.floor(blurbHeight / lineHeight),
		buyY = buyY,
		buyHeight = PANEL.BUY_PX,
		rowHeight = PANEL.ROW_PX,
		headerHeight = PANEL.HEADER_ROW_PX,
		gap = PANEL.GAP,
	}
end

-- THE SCREEN THIS CLIENT HAS, or the phone-sized default when there is no camera to ask (a spec
-- running before the camera exists, which `Hud` already guards everywhere else). The DEFAULT IS THE
-- SMALL ONE on purpose: a layout that guessed big would overflow a phone, and one that guesses small
-- only wastes pixels for one frame.
local function screenSize(): Vector2
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return Vector2.new(400, 800)
	end
	local size = camera.ViewportSize
	if size.X < 100 or size.Y < 100 then
		return Vector2.new(400, 800)
	end
	return size
end

-- WHAT `Hud.build` SIZES THE FRAME WITH -- one function decides the box, which is the arrangement
-- `ShopPanel.heightFor` had and this keeps: the Hud creates the rectangle from the panel's own
-- number, and from `build` onward this module is the only writer of it.
function ShopPanel.panelSize(): UDim2
	local size = screenSize()
	local layout = ShopPanel.layoutFor(size.X, size.Y)
	return UDim2.fromOffset(layout.width, layout.height)
end

-- ---------------------------------------------------------------- the picture, built once

-- EVERY CHILD SITS ABOVE THE PANEL'S OWN ZINDEX, and task 124's measured defect is why: with the
-- panel opaque at ZIndex 10 and its labels at the default 1, the whole report came out as an EMPTY
-- BLACK RECTANGLE -- the text was being drawn BEHIND its own background.
local function label(parent: Instance, name: string, size: number, position: UDim2, width: number): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.ZIndex = Z + 3
	-- THE SAME BLACK OUTLINE every other label in this Hud wears: over a bright forest a thin Code
	-- glyph with no stroke is the half of the text that disappears first.
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = text
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.Code
	text.TextSize = size
	text.TextColor3 = Drive.CONFIG.TEXT_COLOR
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Position = position
	text.Size = UDim2.fromOffset(width, size + 6)
	text.Text = ""
	text.Parent = parent
	return text
end

-- A BUTTON A THUMB CAN HIT: `Shop.CONFIG.BUTTON_PX` (48) tall at the smallest, over the 44 px
-- Roblox's own tutorial sets as the minimum, and driven by `Activated` -- one event for a click AND
-- a tap.
local function button(parent: Instance, name: string, width: number, height: number?): TextButton
	local made = Instance.new("TextButton")
	made.Name = name
	made.AutoButtonColor = false
	made.BackgroundColor3 = ShopPanel.LOOK.ROW_COLOR
	made.BorderSizePixel = 0
	made.Font = Enum.Font.Code
	made.TextSize = TEXT_SIZE
	made.TextColor3 = Drive.CONFIG.TEXT_COLOR
	made.Text = ""
	made.Size = UDim2.fromOffset(width, height or CONFIG.BUTTON_PX)
	made.ZIndex = Z + 3
	local rim = Instance.new("UIStroke")
	rim.Thickness = 1
	rim.Color = ShopPanel.LOOK.RIM_COLOR
	rim.Transparency = 0.5
	rim.Parent = made
	made.Parent = parent
	return made
end

local function corner(instance: Instance, radius: number)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, radius)
	round.Parent = instance
end

-- HOW TALL THE SIDE MENU'S CANVAS IS, for however many shelves and rows the catalogue has. PURE, so
-- the scroll is a spec and not a screenshot: a list that could not reach its last row would be a
-- shop with an item nobody can buy.
function ShopPanel.canvasHeightFor(groups: number, rows: number): number
	local cells = groups + rows
	if cells <= 0 then
		return 0
	end
	return groups * PANEL.HEADER_ROW_PX + rows * PANEL.ROW_PX + (cells - 1) * PANEL.GAP
end

-- THE SIDE MENU, BUILT ONCE FROM THE CATALOGUE'S OWN SHAPE. The shelves and the items in them are
-- STATIC DATA -- `Shop.ORDER` and each row's `category` -- so the instances are made here and only
-- their words, colours and badges are written per render. That is the discipline every panel in this
-- Hud keeps, and the reason is the one task 124 measured: a panel that rebuilds its own children is
-- a panel whose `ZIndex`, parent and visibility have to be got right once per frame instead of once.
--
-- A `UIListLayout` STACKS THEM, so no row carries a Y coordinate: adding a sixth item moves
-- everything below it by itself, and `Shop.rowsOk` is what keeps the count under `MAX_ITEMS`.
local function buildMenu(parent: ScrollingFrame)
	table.clear(menu)
	table.clear(headers)
	local stack = Instance.new("UIListLayout")
	stack.FillDirection = Enum.FillDirection.Vertical
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Padding = UDim.new(0, PANEL.GAP)
	stack.Parent = parent
	local order = 0
	-- THE SHELVES, IN THE CATALOGUE'S OWN ORDER, over the rows each one holds. `Shop.groups` is the
	-- pure function both this and the render read, so a shelf drawn here and a row drawn there can
	-- never disagree about which items are on it.
	for _, group in ipairs(ShopData.groups(ShopData.rowsFor(nil, nil, nil, true))) do
		order += 1
		local header = label(parent, string.format("Header_%s", group.category), SMALL_SIZE, UDim2.new(), 0)
		header.LayoutOrder = order
		header.Size = UDim2.new(1, 0, 0, PANEL.HEADER_ROW_PX)
		header.TextColor3 = ShopPanel.LOOK.HEADER_COLOR
		header.TextYAlignment = Enum.TextYAlignment.Bottom
		header.Text = group.label
		table.insert(headers, header)
		for _, row in ipairs(group.rows) do
			order += 1
			local id = row.id
			local made = button(parent, string.format("Item_%s", id), 0, PANEL.ROW_PX)
			made.LayoutOrder = order
			made.Size = UDim2.new(1, 0, 0, PANEL.ROW_PX)
			made.Text = ""
			made.ZIndex = Z + 2
			corner(made, 6)
			local name = label(made, "Name", TEXT_SIZE, UDim2.fromOffset(8, 6), 0)
			name.Size = UDim2.new(1, -16, 0, TEXT_SIZE + 6)
			local meta = label(made, "Meta", SMALL_SIZE, UDim2.fromOffset(8, 6 + TEXT_SIZE + 6), 0)
			meta.Size = UDim2.new(1, -16, 0, SMALL_SIZE + 6)
			-- THE ID IS CLOSED OVER AND NOTHING ELSE IS. A click SELECTS; it never buys and never
			-- reads a price, so a row drawing a different item after a redraw cannot buy the one it
			-- used to show -- and there is nothing here that could be out of date.
			made.Activated:Connect(function()
				ShopPanel.select(id)
			end)
			table.insert(menu, { id = id, row = made })
		end
	end
	parent.CanvasSize = UDim2.fromOffset(0, ShopPanel.canvasHeightFor(#headers, #menu))
end

-- THE RIGHT-HAND COLUMN: the picture, the name, the two short lines, the paragraph and the one
-- button. Built once, written per render.
local function buildDetail(parent: Frame)
	local frame = Instance.new("ViewportFrame")
	frame.Name = "Picture"
	frame.BackgroundColor3 = ShopPanel.LOOK.IMAGE_COLOR
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	frame.Position = UDim2.new()
	frame.Size = UDim2.new(1, 0, 0, PANEL.IMAGE_MIN)
	frame.ZIndex = Z + 2
	-- THE VIEWPORT'S OWN LIGHT, because it has no Lighting service of its own: a model in a
	-- `ViewportFrame` is lit by these three properties and by nothing else, and left at the defaults
	-- a dark gun on a dark panel is a silhouette of a gun.
	frame.LightDirection = ShopDisplay.LIGHT_DIRECTION
	frame.LightColor = ShopDisplay.LIGHT_COLOR
	frame.Ambient = ShopDisplay.AMBIENT
	corner(frame, 6)
	frame.Parent = parent
	viewport = frame

	local camera = Instance.new("Camera")
	camera.Name = "PictureCamera"
	camera.FieldOfView = ShopDisplay.FOV_DEG
	camera.Parent = frame
	-- A `ViewportFrame` RENDERS THROUGH ITS OWN `CurrentCamera` AND NOT THE WORKSPACE'S. Forgetting
	-- this line is the way a viewport comes out as a flat colour with the model inside it.
	frame.CurrentCamera = camera
	viewportCamera = camera

	nameLabel = label(parent, "ItemName", NAME_SIZE, UDim2.fromOffset(0, PANEL.IMAGE_MIN + 8), 0);
	(nameLabel :: TextLabel).Size = UDim2.new(1, 0, 0, NAME_SIZE + 6)

	priceLabel = label(parent, "ItemPrice", TEXT_SIZE, UDim2.fromOffset(0, PANEL.IMAGE_MIN + 34), 0);
	(priceLabel :: TextLabel).Size = UDim2.new(1, 0, 0, TEXT_SIZE + 6);
	(priceLabel :: TextLabel).TextColor3 = ShopPanel.LOOK.COIN_COLOR

	unlockLabel = label(parent, "ItemUnlock", SMALL_SIZE, UDim2.fromOffset(0, PANEL.IMAGE_MIN + 54), 0);
	(unlockLabel :: TextLabel).Size = UDim2.new(1, 0, 0, SMALL_SIZE + 6);
	(unlockLabel :: TextLabel).TextTransparency = 0.25

	blurbLabel = label(parent, "ItemBlurb", SMALL_SIZE, UDim2.fromOffset(0, PANEL.IMAGE_MIN + 76), 0);
	-- THE ONE WRAPPED PARAGRAPH IN THIS HUD. `TextWrapped` plus `TextYAlignment.Top` is what makes
	-- Karen's *"explanation what is that"* read as a paragraph instead of one clipped line, and the
	-- height is whatever is left between the unlock line and the button -- written by `relayout`.
	(blurbLabel :: TextLabel).TextWrapped = true
	(blurbLabel :: TextLabel).TextYAlignment = Enum.TextYAlignment.Top;
	(blurbLabel :: TextLabel).RichText = false

	local buy = button(parent, "Buy", 0, PANEL.BUY_PX)
	buy.Size = UDim2.new(1, 0, 0, PANEL.BUY_PX)
	buy.AnchorPoint = Vector2.new(0, 1)
	buy.Position = UDim2.fromScale(0, 1)
	buy.TextSize = TEXT_SIZE + 2
	corner(buy, 6)
	-- THE SELECTED ITEM IS READ AT PRESS TIME out of the CURRENT payload, so the button can only ever
	-- buy the thing whose page is on screen -- and whether it may is still the server's word.
	buy.Activated:Connect(function()
		ShopPanel.pressSelected()
	end)
	buyButton = buy
end

local function build(frame: Frame)
	panel = frame
	title = label(frame, "Title", TITLE_SIZE, UDim2.fromOffset(PAD, 8), 0);
	(title :: TextLabel).Size = UDim2.new(1, -2 * PAD - CONFIG.BUTTON_PX, 0, TITLE_SIZE + 6);
	(title :: TextLabel).Text = TEXT.TITLE

	-- THE CLOSE BUTTON, and it is not a nicety: on a touch device it is the only way out of this
	-- panel other than walking away, because `Escape` belongs to the Roblox menu and cannot be bound
	-- (`ReportPanel.bind`'s own note).
	local close = button(frame, "Close", CONFIG.BUTTON_PX)
	close.Text = TEXT.CLOSE_GLYPH
	close.TextSize = TITLE_SIZE
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -PAD, 0, 8)
	corner(close, 6)
	close.Activated:Connect(function()
		ShopPanel.setOpen(false)
	end)

	balance = label(frame, "Balance", TEXT_SIZE, UDim2.fromOffset(PAD, 8 + TITLE_SIZE + 8), 0);
	(balance :: TextLabel).Size = UDim2.new(1, -2 * PAD - CONFIG.BUTTON_PX, 0, TEXT_SIZE + 6);
	(balance :: TextLabel).TextColor3 = ShopPanel.LOOK.COIN_COLOR

	-- THE SIDE MENU. A `ScrollingFrame` because the catalogue may outgrow the column: five items and
	-- four shelves is 404 px against the 398 a 400 x 800 phone has, so this list ALREADY scrolls on
	-- the screen `hud_clarity.spec` measures -- and a list that could not would be a shop with a
	-- hidden item.
	local column = Instance.new("ScrollingFrame")
	column.Name = "Menu"
	column.BackgroundColor3 = ShopPanel.LOOK.COLUMN_COLOR
	column.BackgroundTransparency = 0.25
	column.BorderSizePixel = 0
	column.ScrollBarThickness = 4
	column.ScrollBarImageTransparency = 0.4
	column.ScrollingDirection = Enum.ScrollingDirection.Y
	column.CanvasSize = UDim2.new()
	column.ZIndex = Z + 1
	corner(column, 6)
	column.Parent = frame
	list = column

	local right = Instance.new("Frame")
	right.Name = "Detail"
	right.BackgroundTransparency = 1
	right.BorderSizePixel = 0
	right.ZIndex = Z + 1
	right.Parent = frame
	detail = right

	buildMenu(column)
	buildDetail(right)

	footer = label(frame, "Footer", SMALL_SIZE, UDim2.fromOffset(PAD, 0), 0);
	(footer :: TextLabel).Size = UDim2.new(1, -2 * PAD, 0, SMALL_SIZE + 6);
	(footer :: TextLabel).TextTransparency = 0.15

	ShopPanel.relayout()
end

-- ---------------------------------------------------------------- the rectangles, written
--
-- ONE WRITER OF EVERY POSITION AND SIZE IN THIS PANEL, from the ONE pure layout. Called at build and
-- whenever the viewport changes size, so a phone rotated on its side is the same panel re-measured
-- rather than a second layout path.
function ShopPanel.relayout()
	local frame = panel
	if frame == nil then
		return
	end
	stats.layouts += 1
	local size = screenSize()
	screenWas = size
	local layout = ShopPanel.layoutFor(size.X, size.Y)
	frame.Size = UDim2.fromOffset(layout.width, layout.height)
	if list ~= nil then
		(list :: ScrollingFrame).Position = UDim2.fromOffset(layout.listX, layout.listY);
		(list :: ScrollingFrame).Size = UDim2.fromOffset(layout.listWidth, layout.listHeight);
		(list :: ScrollingFrame).CanvasSize = UDim2.fromOffset(0, ShopPanel.canvasHeightFor(#headers, #menu))
	end
	if detail ~= nil then
		(detail :: Frame).Position = UDim2.fromOffset(layout.detailX, layout.listY);
		(detail :: Frame).Size = UDim2.fromOffset(layout.detailWidth, layout.listHeight)
	end
	if viewport ~= nil then
		(viewport :: ViewportFrame).Size = UDim2.new(1, 0, 0, layout.imageHeight)
	end
	if nameLabel ~= nil then
		(nameLabel :: TextLabel).Position = UDim2.fromOffset(0, layout.nameY)
	end
	if priceLabel ~= nil then
		(priceLabel :: TextLabel).Position = UDim2.fromOffset(0, layout.priceY)
	end
	if unlockLabel ~= nil then
		(unlockLabel :: TextLabel).Position = UDim2.fromOffset(0, layout.unlockY)
	end
	if blurbLabel ~= nil then
		(blurbLabel :: TextLabel).Position = UDim2.fromOffset(0, layout.blurbY);
		(blurbLabel :: TextLabel).Size = UDim2.new(1, 0, 0, layout.blurbHeight)
	end
	if footer ~= nil then
		(footer :: TextLabel).Position = UDim2.fromOffset(PAD, layout.height - PANEL.FOOTER_PX + 6)
	end
end

-- ---------------------------------------------------------------- the words, pure and exported

-- PURE and exported for `ReportPanel.listRowText`'s reason: what the panel SAYS has to be a spec
-- rather than a screenshot.

-- THE FIRST LINE OF A MENU ROW: the item's name, as the server sent it.
function ShopPanel.rowNameFor(row: any): string
	if row == nil then
		return ""
	end
	return tostring(row.label)
end

-- THE SECOND LINE OF A MENU ROW: the price, and then the one word that says why this row is not a
-- purchase today. `OWNED` wins over everything, because a thing you have has no price any more.
function ShopPanel.rowMetaFor(row: any): string
	if row == nil then
		return ""
	end
	if row.owned == true then
		return TEXT.OWNED_TAG
	end
	local badge = ShopPanel.badgeFor(row)
	if badge == "" then
		return string.format(TEXT.PRICE, row.price)
	end
	return string.format("%s  %s", string.format(TEXT.PRICE, row.price), badge)
end

-- THE ONE WORD A ROW WEARS, or "" for a row you may simply buy. It is the row's own `WireRow` read
-- out loud, so the server's decision is the only thing on screen.
function ShopPanel.badgeFor(row: any): string
	if row == nil then
		return ""
	end
	if row.owned == true then
		return TEXT.OWNED_TAG
	end
	if row.sale ~= true then
		return TEXT.SOON_TAG
	end
	if row.locked == true then
		return string.format(TEXT.LOCKED_TAG, row.hunts)
	end
	if row.afford ~= true then
		return TEXT.POOR_TAG
	end
	return ""
end

-- THE COLOUR OF A BADGE, which is the whole reason a badge is worth drawing: green for a thing you
-- have, amber for a rung the ladder is holding back, and the plain text colour for a price.
function ShopPanel.badgeColorFor(row: any): Color3
	if row ~= nil and row.owned == true then
		return ShopPanel.LOOK.OWNED_COLOR
	end
	if row ~= nil and (row.locked == true or row.sale ~= true or row.afford ~= true) then
		return ShopPanel.LOOK.LOCKED_COLOR
	end
	return ShopPanel.LOOK.COIN_COLOR
end

-- THE WORD ON THE BIG BUTTON. `buyable` is the ONE field it reads -- computed once, on the server --
-- so a greyed-out button and an accepted purchase cannot disagree (design hazard 10).
function ShopPanel.buttonTextFor(row: any): string
	if row == nil then
		return ""
	end
	if row.buyable == true then
		return TEXT.BUY
	end
	if row.owned == true then
		return TEXT.OWNED_TAG
	end
	if row.sale ~= true then
		return TEXT.SOON_TAG
	end
	if row.locked == true then
		return string.format(TEXT.LOCKED_TAG, row.hunts)
	end
	return TEXT.POOR_TAG
end

-- WHAT THE UNLOCK LINE SAYS: the rule, and how far off he is from it. The ROW carries both facts --
-- the gate and whether he is behind it -- so this prints and decides nothing.
function ShopPanel.unlockTextFor(row: any, hunts: number?): string
	if row == nil then
		return ""
	end
	if row.hunts <= 0 then
		return TEXT.UNLOCK_OPEN
	end
	if row.locked == true then
		local left = row.hunts - (hunts or 0)
		if left > 0 then
			return string.format(TEXT.UNLOCK_LEFT, left)
		end
	end
	return string.format(TEXT.UNLOCK_AT, row.hunts)
end

function ShopPanel.balanceLineFor(state: any): string
	if state ~= nil and state.coinsOn == false then
		return TEXT.CLOSED
	end
	local coins = state and state.balance
	return string.format(
		TEXT.BALANCE,
		-- `--` AND NOT `0` for a player with no open profile, which is `Economy.balanceOf`'s own rule:
		-- nil is not the same fact as a balance of zero.
		if type(coins) == "number" then string.format("%d", coins) else "--",
		(state and state.hunts) or 0
	)
end

-- WHAT THE FOOTER SAYS: the last refusal for as long as `MESSAGE_SECONDS`, and otherwise the one
-- hint. PURE in its inputs so a spec can drive the expiry with a number.
function ShopPanel.footerFor(line: string?, at: number, now: number): string
	if line ~= nil and now - at <= ShopPanel.LOOK.MESSAGE_SECONDS then
		return line
	end
	return TEXT.HINT
end

-- ---------------------------------------------------------------- what is selected

-- THE ROW THE SERVER SENT FOR AN ID, out of the CURRENT payload. nil for an id the payload has no row
-- for, which is what an empty detail pane is drawn from.
function ShopPanel.rowFor(id: string?): any
	if id == nil then
		return nil
	end
	for _, row in ipairs((payload and payload.rows) or {}) do
		if row.id == id then
			return row
		end
	end
	return nil
end

-- WHICH ITEM A FRESHLY OPENED PANEL SHOWS: the first one in the side menu's own order, so the right
-- column is never blank while there is something to show.
local function firstId(): string?
	local order = ShopData.menuOrder((payload and payload.rows) or nil)
	if #order > 0 then
		return order[1]
	end
	return if #menu > 0 then menu[1].id else nil
end

-- CLICKING A ROW SELECTS IT AND DOES NOTHING ELSE -- no money, no remote, no decision. The picture
-- is rebuilt here rather than per frame, because building a model is the expensive half and the
-- selection is the only thing that changes which model it is.
function ShopPanel.select(id: string?)
	if id == nil or selected == id then
		return
	end
	selected = id
	stats.selects += 1
	ShopPanel.showPicture(id)
	ShopPanel.render()
end

-- ---------------------------------------------------------------- the picture

-- THE MODEL IN THE VIEWPORT, SWAPPED. One model at a time, the old one destroyed, so an open panel
-- holds one item's parts and not one per row the player has ever clicked.
function ShopPanel.showPicture(id: string?)
	local frame = viewport
	if frame == nil then
		return
	end
	if viewportModel ~= nil then
		(viewportModel :: Model):Destroy()
		viewportModel = nil
	end
	viewportId = nil
	local model = ShopDisplay.build(id)
	if model == nil then
		return
	end
	model.Parent = frame
	viewportModel = model
	viewportId = id
	pictureCentre, pictureRadius = ShopDisplay.frameOf(model)
	viewportBuiltAt = os.clock()
	stats.pictures += 1
	ShopPanel.aim(0)
end

-- WHERE THE VIEWPORT'S CAMERA IS AT THIS ANGLE. The framing is `ShopDisplay`'s pure arithmetic and
-- this is the one line that writes it.
function ShopPanel.aim(angleDeg: number)
	local camera = viewportCamera
	if camera == nil or viewportModel == nil then
		return
	end
	camera.CFrame = ShopDisplay.cameraCFrame(pictureCentre, pictureRadius, angleDeg, ShopDisplay.viewFor(viewportId))
end

-- ONE STEP OF THE TURN, called by `Hud.renderObjective` -- the Hud's one per-frame evaluation, which
-- already tells this panel where the player is standing. NO SECOND LOOP: a module with a
-- `RenderStepped` connection of its own would be a second owner of this client's frame.
--
-- IT DOES NOTHING WHILE THE PANEL IS SHUT, which is the whole cost argument for the viewport: one
-- camera write per frame while a player is standing at a counter reading a page, and not one byte
-- while he is hunting.
--
-- AND IT IS WHERE A LATE MESH LANDS. `ShopDisplay.rebuildWanted` is true while the rifle's meshes
-- are still coming down -- a player who has only ever carried the shotgun has never asked for them --
-- so the picture is drawn again, once a second, until it is the real gun (task 133's stale-and-rebuild
-- path, which the viewmodel already takes for the same reason).
function ShopPanel.step(now: number?)
	if not open then
		return
	end
	-- A WINDOW DRAGGED OR A PHONE TURNED WHILE THE PANEL IS OPEN. One `Vector2` comparison a frame,
	-- and `relayout` only runs when the answer actually changed -- the edge-triggered discipline every
	-- other write in this file keeps.
	if screenSize() ~= screenWas then
		ShopPanel.relayout()
	end
	if viewportModel == nil then
		return
	end
	local clock = now or os.clock()
	if ShopDisplay.rebuildWanted() and clock - viewportBuiltAt >= 1 then
		ShopPanel.showPicture(viewportId)
	end
	ShopPanel.aim(ShopDisplay.spinDegAt(clock))
end

-- ---------------------------------------------------------------- drawing

function ShopPanel.render(now: number?)
	local frame = panel
	if frame == nil then
		return
	end
	stats.renders += 1
	local state = payload;
	(balance :: TextLabel).Text = ShopPanel.balanceLineFor(state)

	-- THE SIDE MENU: one pass over the rows that ARRIVED, by id. A row the payload does not carry is
	-- hidden rather than left reading what it said last time.
	local wire = (state and state.rows) or {}
	local byId: { [string]: any } = {}
	for _, row in ipairs(wire) do
		byId[row.id] = row
	end
	for _, entry in ipairs(menu) do
		local row = byId[entry.id]
		local name = entry.row:FindFirstChild("Name") :: TextLabel?
		local meta = entry.row:FindFirstChild("Meta") :: TextLabel?
		if row == nil then
			entry.row.Visible = false
			continue
		end
		if name then
			name.Text = ShopPanel.rowNameFor(row)
		end
		if meta then
			meta.Text = ShopPanel.rowMetaFor(row)
			meta.TextColor3 = ShopPanel.badgeColorFor(row)
		end
		-- THE SELECTED ROW IS THE ONLY ONE WEARING THE GREEN, re-decided every render out of one
		-- variable, so two rows can never look selected at once.
		entry.row.BackgroundColor3 = if entry.id == selected
			then ShopPanel.LOOK.ROW_SELECTED_COLOR
			else ShopPanel.LOOK.ROW_COLOR
		entry.row.BackgroundTransparency = if entry.id == selected then 0 else 0.35
		entry.row.Visible = true
	end

	-- THE DETAIL PANE, OUT OF THE CURRENT PAYLOAD AND NEVER OUT OF WHAT WAS TRUE WHEN THE ROW WAS
	-- CLICKED. That is what makes the big button honest while the panel is open: a drive that pays
	-- out, or a purchase that completes, arrives as a new state, and this runs again.
	local row = ShopPanel.rowFor(selected);
	(nameLabel :: TextLabel).Text = if row then ShopPanel.rowNameFor(row) else TEXT.PICK;
	(priceLabel :: TextLabel).Text = if row then string.format(TEXT.PRICE, row.price) else ""
	(unlockLabel :: TextLabel).Text = if row then ShopPanel.unlockTextFor(row, state and state.hunts) else ""
	(blurbLabel :: TextLabel).Text = if row then tostring(row.blurb) else ""
	(buyButton :: TextButton).Text = ShopPanel.buttonTextFor(row);
	-- GREEN IS THE ONE YOU MAY PRESS. A locked rung is still SHOWN, because it is information --
	-- Karen's ladder has four rungs and a shop that hid one would tell her it is shorter than it is.
	(buyButton :: TextButton).BackgroundColor3 = if row ~= nil and row.buyable == true
		then ShopPanel.LOOK.BUY_COLOR
		else ShopPanel.LOOK.DEAD_COLOR;
	(buyButton :: TextButton).Visible = row ~= nil
	(footer :: TextLabel).Text = ShopPanel.footerFor(message, messageAt, now or os.clock())
end

-- ---------------------------------------------------------------- open and close

function ShopPanel.setOpen(next_: boolean)
	if open == next_ then
		return
	end
	open = next_
	local frame = panel
	if frame then
		frame.Visible = open
	end
	if open then
		stats.opens += 1
		-- THE SCREEN MAY HAVE CHANGED SIZE WHILE THE PANEL WAS SHUT (a window dragged, a phone
		-- turned), and this is the cheapest place to find out: once per walk-in, not once per frame.
		ShopPanel.relayout()
		-- THE MOUSE AND THE TRIGGER, through the two doors that already exist: `Cursor.requestFree`
		-- is what lets him click BUY in first person, and `Input.requestHold` is what stops the same
		-- click firing the gun. Both are reason-keyed, so the shop releases exactly its own request
		-- (`ReportPanel.setOpen`'s shape, tag "shop").
		if Cursor ~= nil then
			Cursor.requestFree("shop")
		end
		if WeaponInput ~= nil then
			WeaponInput.requestHold("shop")
		end
		-- SOMETHING IS ALWAYS SELECTED while the panel is open, so Karen's *"image and explanation"*
		-- is what she sees on opening rather than an empty half-panel waiting for a click.
		if selected == nil then
			ShopPanel.select(firstId())
		elseif viewportId ~= selected then
			ShopPanel.showPicture(selected)
		end
		ShopPanel.ask()
	else
		stats.closes += 1
		if Cursor ~= nil then
			Cursor.release("shop")
		end
		if WeaponInput ~= nil then
			WeaponInput.releaseHold("shop")
		end
	end
	ShopPanel.render()
end

-- ---------------------------------------------------------------- the counter and the keeper

-- IS HE AT THE COUNTER? TOLD to this module and never read here -- `Rail.setWeapon`'s stated rule
-- (*"`hasWeapon` is TOLD to this module by the Hud, never read here"*), so there is one reader of
-- the player's position in the Hud and this panel learns nothing about worlds.
--
-- SINCE TASK 181 IT ONLY EVER CLOSES. Walking up to the counter opens nothing: the shopkeeper's
-- prompt is the one way in (Karen: *"a person bot who you need to click E"*). Walking away shuts
-- the panel, and the distance it shuts at is `Shop.CONFIG.REACH_STUDS` -- THE SAME NUMBER THE
-- SERVER REFUSES A PURCHASE AT, so "the panel is open but every press is refused" cannot happen.
--
-- EDGE-TRIGGERED: one write per change, not one per frame, which is `Lobby`'s own discipline for an
-- attribute that used to be written fifty times per walk-in.
function ShopPanel.setNear(next_: boolean)
	next_ = next_ == true and enabled
	if near == next_ then
		return
	end
	near = next_
	if not near then
		ShopPanel.setOpen(false)
	end
end

-- THE SHOPKEEPER'S PROMPT, TOLD to this module exactly as `near` is: the Hud resolves it through
-- `Lobby.shopPrompt()` on the evaluation it already runs, and this connects to it. Anything
-- carrying a `Triggered` signal is accepted -- which is not laxity but the seam that makes the
-- wiring testable at all, since a spec cannot fire a real `ProximityPrompt` (`Rail.press`'s stated
-- limit, and that limit is reported rather than papered over).
--
-- EDGE-TRIGGERED ON THE INSTANCE: the same prompt handed in twice does nothing, and a REBUILT lodge
-- (a new prompt) drops the old connection rather than leaving this panel listening to a prompt that
-- is no longer in the DataModel.
function ShopPanel.setPrompt(next_: any)
	if prompt == next_ then
		return
	end
	if promptConnection ~= nil then
		pcall(function()
			(promptConnection :: any):Disconnect()
		end)
		promptConnection = nil
	end
	prompt = next_
	if next_ == nil then
		return
	end
	local ok, connection = pcall(function()
		return next_.Triggered:Connect(function()
			ShopPanel.onPromptTriggered()
		end)
	end)
	-- ANY CONNECTION OBJECT, not only an `RBXScriptConnection`, and that is the same decision as
	-- taking anything with a `Triggered` signal: a `BindableEvent` fires DEFERRED (Roblox's signal
	-- behaviour since 2022), so a spec driving one could never read the result in the same frame --
	-- measured on task 181's first harness run. The fake the spec hands in is therefore a plain
	-- synchronous signal, and what it drives is this exact line.
	if ok and connection ~= nil then
		promptConnection = connection
		stats.prompts += 1
	else
		prompt = nil
	end
end

-- Whether this module is listening to a prompt right now -- for a spec, and for a console probe
-- that wants to know why `E` did nothing.
function ShopPanel.hasPrompt(): boolean
	return promptConnection ~= nil
end

-- THE FLAG'S VALUE, AND IT IS SETTABLE BECAUSE CLAUDE.md REQUIRES IT TO BE: *"a flagged path must
-- be reachable by parameter as well as by flag, or its two states cannot be tested while the flag
-- sits at one of them"*. `ShopPanel.start` reads `SHOP` once, at the boundary, and this is the same
-- value by another door -- for the spec that has to drive the lit path while the row sits at
-- `false`. Nothing in `src/` calls it.
function ShopPanel.setEnabled(on: boolean)
	enabled = on == true
	if not enabled then
		ShopPanel.setOpen(false)
	end
end

function ShopPanel.isEnabled(): boolean
	return enabled
end

-- WHAT THE PROMPT DOES: it OPENS, and never toggles. A prompt you press while the panel is already
-- open is a prompt you pressed because the panel was in the way of the counter, not a request to
-- shut it -- and the panel has a CLOSE button and a walk-away rule for that.
--
-- THE FLAG IS CHECKED HERE TOO, not only at `setNear`: with `SHOP` off there is no keeper and no
-- prompt, but an injected one must not open a panel this build does not have.
function ShopPanel.onPromptTriggered()
	stats.triggers += 1
	if not enabled then
		return
	end
	ShopPanel.setOpen(true)
end

-- ---------------------------------------------------------------- the wire

function ShopPanel.ask()
	if remotes == nil then
		return
	end
	stats.asks += 1
	remotes.ShopRequest:FireServer({ kind = ShopData.KIND.OPEN })
end

-- WHAT A PRESS SENDS: AN ITEM ID AND NOTHING ELSE. Never a price -- the server reads that from the
-- catalogue (Roblox's own security page, and the note's section 2.2).
--
-- PUBLIC AND NAMED, for `Rail.press`'s stated reason: a spec cannot fire `GuiButton.Activated` and
-- the harness cannot synthesise a tap, so this is the seam that makes the buttons testable at all --
-- and what it proves is the ACTION, not the touch. That limit is reported, not papered over.
function ShopPanel.press(id: string?): boolean
	stats.presses += 1
	if type(id) ~= "string" or remotes == nil then
		return false
	end
	stats.sent += 1
	remotes.ShopRequest:FireServer({ kind = ShopData.KIND.BUY, item = id })
	return true
end

-- THE BIG BUTTON'S ACTION: buy the thing whose page is on screen.
--
-- A ROW THE SERVER DREW AS DEAD IS NOT SENT, and the line it would have refused with is printed from
-- the SAME `WireRow` instead. The server is still the only thing that decides -- this saves a round
-- trip for a press on "OWNED" and keeps the footer's voice in one table.
function ShopPanel.pressSelected(): boolean
	local row = ShopPanel.rowFor(selected)
	if row == nil then
		return false
	end
	if row.buyable ~= true then
		message = ShopPanel.badgeFor(row)
		messageAt = os.clock()
		ShopPanel.render()
		return false
	end
	return ShopPanel.press(row.id)
end

-- WHAT THE SERVER SAID. Kept WHOLE and never edited: it is the only thing that changes what this
-- panel believes about his money and his things.
--
-- IT RENDERS WHETHER OR NOT THE PANEL IS OPEN (task 196), which task 178 did not: the payload decides
-- every word on screen, so a panel that kept the old drawing while holding a new payload would show
-- a stale price for one frame after the next open. One pass over five rows is cheaper than the class
-- of bug.
function ShopPanel.onState(state: any, now: number?)
	if type(state) ~= "table" then
		return
	end
	stats.states += 1
	payload = state
	if state.bought ~= nil then
		local row = ShopData.row(state.bought)
		message = string.format(TEXT.BOUGHT, if row then row.label else tostring(state.bought))
		messageAt = now or os.clock()
	elseif state.refused ~= nil then
		message = ShopData.noticeFor(state.refused, state.refusedNumber)
		messageAt = now or os.clock()
	end
	-- A PAYLOAD IS ALSO WHAT TELLS THIS PANEL WHICH ITEMS EXIST, so the first state is where a
	-- selection comes from when nothing has been clicked.
	if selected == nil then
		ShopPanel.select(firstId())
	end
	ShopPanel.render(now)
end

function ShopPanel.start(frame: Frame, collaborators: any)
	if started then
		return
	end
	started = true
	Cursor = collaborators and collaborators.Cursor
	WeaponInput = collaborators and collaborators.Input
	remotes = collaborators and collaborators.remotes
	-- THE FLAG, READ AT THIS BOUNDARY AND PASSED INWARD (CLAUDE.md, feature flags). `enabled = false`
	-- means `setNear` never opens anything and no key is ever bound, which is the game before task
	-- 178 -- and both branches stay reachable by parameter, which is what a spec drives.
	enabled = if collaborators ~= nil and collaborators.enabled ~= nil
		then collaborators.enabled == true
		else ShopData.isOn()
	build(frame)
	frame.Visible = false
	if remotes ~= nil then
		remotes.ShopState.OnClientEvent:Connect(function(state)
			ShopPanel.onState(state)
		end)
	end
end

return ShopPanel
