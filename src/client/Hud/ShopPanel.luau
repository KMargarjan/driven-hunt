--!strict
-- Hud.ShopPanel: THE ONE WRITER of everything inside the `ShopPanel` frame -- its `Visible`, its
-- `Size` and every pixel in it -- the one listener of the shopkeeper's `ProximityPrompt`, and this
-- client's one door onto `ReplicatedStorage.Shop.Remotes` (CLAUDE.md rule 3).
--
-- KAREN, 2026-10-13: *"Hunting house where inside can shop things"*; 2026-10-14: *"in lobby has to
-- be a person bot who you need to click E to get access to shop"*; 2026-10-15: *"menus for buying
-- things has to be better more nicer like side menu with click and then shows in right side image
-- and explanation what is that"*; and 2026-10-16, looking at that: *"make nicer design for menu /
-- more intutive more modern / nicer shells ect / license nicer and font give this to designer to
-- decide how it should look"*.
--
-- SO THE LOOK IS THE DESIGNER'S AND NOT THIS FILE'S. **The Designer's spec, 2026-10-16** ("Lodge
-- Ledger") is the source for every number, colour, font and state below, and it is quoted in the
-- research note. What this module still owns is the SEAM: one pure `layoutFor`, the words in
-- `Shop.CONFIG.TEXT`, the models in `Hud.ShopDisplay`, and the rule that the panel draws what
-- arrived and decides nothing.
--
--   the panel is a lit display case in a dark lodge: warm charcoal-brown, cream type, brass
--   hairlines, forest green for what you own, blaze orange for the one thing you can press.
--   ONE ACCENT, ONE MEANING -- orange = act, green = already yours, amber = the ladder is holding
--   it back, clay = you are short of coins.
--
-- TWO LAYOUTS, ONE PANEL (spec 3). A wide panel is a side menu and a detail column; a phone STACKS
-- -- a horizontally scrolling strip of cards under the header, the item's page under that -- because
-- *"at 376 px the detail column would be 178 px wide"*. `layoutFor` answers `mode` and both sets of
-- rectangles; `relayout` shows one and hides the other. Nothing is rebuilt when the screen changes.
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
-- HOW YOU GET OUT: the X in the corner, and walking away from the counter. **`Escape` IS NOT
-- BINDABLE** -- it belongs to the Roblox menu (`ReportPanel.bind`'s own note) -- so a panel that
-- claimed to close on Escape would be lying. The X is TWO ROTATED FRAMES and not a glyph, which is
-- the spec's own rule (8.7): no glyph is used unless it has been checked in the family that renders
-- it.
--
-- IT DRAWS WHAT ARRIVED AND DECIDES NOTHING. Every word, every price, every tag and the `buyable`
-- of every row is computed ONCE, on the server, by the pure `Shop.rowsFor`, and arrives as a
-- `WireRow`. Here it is also the security of the thing: a client that could decide it owned
-- something would be a client that could grant itself a rifle.
--
-- THE SELECTION IS AN ITEM ID AND NEVER AN INDEX, AND THAT IS NOT A STYLE CHOICE. Everything the
-- detail column says is read out of the CURRENT payload at RENDER time, by id, so a balance that
-- changes while the panel is open (a drive paying out, a purchase completing) redraws the button
-- and the tags with it. A state copied into the pane when the row was clicked is how a greyed-out
-- button and an accepted purchase come to disagree.
--
-- IT HOLDS FIVE PIECES OF STATE AND IS THE ONLY WRITER OF ALL FIVE: `open`, `payload`, `message`,
-- `near`, `selected`.
--
--   ScrollingFrame  https://create.roblox.com/docs/reference/engine/classes/ScrollingFrame
--   UIListLayout    https://create.roblox.com/docs/reference/engine/classes/UIListLayout
--   UIGradient      https://create.roblox.com/docs/reference/engine/classes/UIGradient
--   ViewportFrame   https://create.roblox.com/docs/reference/engine/classes/ViewportFrame
--   GuiButton.Activated  https://create.roblox.com/docs/reference/engine/classes/GuiButton#Activated
--     one event for a click AND a tap, which is why this panel needs no touch branch at all.
--
-- Design: docs/design/shop.md (section 5)
-- Note:   docs/research/2026-10-14-the-shop.md, docs/research/2026-10-15-shop-window.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ShopData = require(ReplicatedStorage:WaitForChild("Shop"))
-- THE ONE FORMATTER OF MONEY (task 221): the symbol, the word and how a negative reads.
local Money = require(ReplicatedStorage:WaitForChild("Money"))
local ShopDisplay = require(script.Parent.ShopDisplay)
-- THE ONE SOURCE for every colour, face, size, radius and duration (task 201, the Designer's
-- design system, 2026-10-17 §1). This file's `LOOK`, `FONT` and `spaced` are now aliases of it.
local Style = require(script.Parent.Style)
-- THE TWO ROLE WORDS, FROM THE MODULE THAT PUTS ONE OF THEM ON THE WIRE (task 229). The server
-- writes `Lobby.ROLE_WISH.BEATER` into the `DHRoleWish` attribute and this panel compares against
-- it, so there is ONE spelling of "beater" in the repository and a typo cannot make a switch that
-- never lights. A read of two frozen strings; `ReplicatedStorage.Lobby` requires nothing of this
-- module back, so there is no cycle.
local LobbyData = require(ReplicatedStorage:WaitForChild("Lobby"))

local ShopPanel = {}

local CONFIG = ShopData.CONFIG
local PANEL = CONFIG.PANEL
local TEXT = CONFIG.TEXT
local Z = PANEL.Z_INDEX
-- THE ROLE SWITCH'S OWN GEOMETRY (task 229): the house style's, in this module's own data table.
local ROLE = PANEL.ROLE_SWITCH

-- THIS MODULE BINDS NO KEY AT ALL SINCE TASK 181, and `E` belongs to the shopkeeper's prompt
-- (`Lobby.CONFIG.LODGE.KEEPER.PROMPT.KEYBOARD_KEY`), which is the one owner of it.

-- ---------------------------------------------------------------- the two faces
--
-- OSWALD FOR TITLES, NAMES AND EVERY NUMBER; BUILDERSANS FOR SENTENCES, BUTTONS AND LABELS (spec 1).
-- *"Oswald is condensed, so `BEATER LICENCE` fits a 228 px column at 16 px without shrinking, and
-- its figures are narrow and even, which is what a price column needs. BuilderSans is Roblox's own
-- UI face and is the most legible thing available at 10-14 px on a phone."*
--
-- `Enum.Font.Code` LEAVES THE SHOP, and with it the black `UIStroke` every other label in this Hud
-- wears: that outline is there to hold text over a sunlit forest, and this panel is opaque.
--
-- THEY ARE EXPORTED SINCE TASK 197, AND THAT IS THE "ONE SOURCE" RULE READ LITERALLY. The shop sets
-- the house style (spec section 8: *"Anything built after it follows these"*), so the pad dialog and
-- its loading banner read these five `Font` values and this file's `LOOK` and `spaced` out of here
-- rather than re-spelling five family paths and forty hexes. A second copy of a palette is a second
-- answer to *"what colour is blaze orange"* -- `docs/PROJECT_CONTEXT.md`'s named failure mode -- and
-- it is exactly how the old dialog came to be `Enum.Font.Code` on a blue-grey panel while the shop
-- beside it was Oswald on charcoal.
-- THEY LIVE IN `Hud.Style` SINCE TASK 201, AND THESE THREE LINES ARE WHAT IS LEFT OF THEM HERE.
-- The Designer's design system, 2026-10-17 (§1, build task A) made the shop's palette, its two
-- faces and its letter-spacing THE WHOLE GAME'S, so the table moved up one level and this file --
-- and `PadPanel`, and `HitCard`, which all read `ShopPanel.LOOK` / `.FONT` / `.spaced` -- reads it
-- back through a thin alias. SAME TABLE, SAME VALUES, so the shop and the pad dialog look exactly
-- as `196-shop-desktop.png` and `t197d-dialog.png` already do: that is task A's only check.
--
-- WHY AN ALIAS AND NOT A RENAME ACROSS THREE FILES: `tests/client/shop_panel.spec.luau` asserts
-- `Panel.LOOK.BLAZE`, `Panel.LOOK.MESSAGE_SECONDS` and `Panel.spaced("AMMO")` by those names, and a
-- field rename across a shared table is this repo's named recurrence (task 196's `Body.SLOTS`).
-- The alias costs three lines and removes the second copy, which is the whole point of task A.
ShopPanel.FONT = Style.FONT
ShopPanel.spaced = Style.spaced
ShopPanel.LOOK = Style.LOOK

local OSWALD_SB = ShopPanel.FONT.OSWALD_SB
local OSWALD_MD = ShopPanel.FONT.OSWALD_MD
local SANS_BOLD = ShopPanel.FONT.SANS_BOLD
local SANS_SEMI = ShopPanel.FONT.SANS_SEMI
local SANS_REG = ShopPanel.FONT.SANS_REG

local spaced = ShopPanel.spaced

local LOOK = ShopPanel.LOOK

-- ---------------------------------------------------------------- state (five values, one writer)
local open = false
local near = false
local payload: any = nil
local message: string? = nil
local messageKind: string? = nil
local messageAt = -math.huge
local selected: string? = nil

local started = false
local prompt: any = nil
local promptConnection: any = nil
local panel: Frame? = nil
local scrim: Frame? = nil
local title: TextLabel? = nil
local coinsValue: TextLabel? = nil
local huntsValue: TextLabel? = nil
local well: ScrollingFrame? = nil
-- THE WELL'S TWO FADE MASKS (task 228, shop2 spec 1.5): a row scrolling under the top or bottom
-- inside edge dissolves instead of being cut off square.
local wellFadeTop: Frame? = nil
-- ---------------- THE ROLE SWITCH (task 229)
--
-- `roleWish` IS THE SERVER'S WORD and this panel's only opinion about it is which half is lit. It is
-- TOLD by the Hud's one evaluation off the `DHRoleWish` attribute; nil means he does not own
-- `ALWAYS HUNTER` and nothing is drawn on either surface.
local roleWish: string? = nil
local roleTeam: string? = nil
local roleAsk: ((string) -> ())? = nil
local rowSwitch: any = nil
local rowBlock: Frame? = nil
local detailSwitch: any = nil
local detailBlock: Frame? = nil
local wellFadeBottom: Frame? = nil
local strip: ScrollingFrame? = nil
local stripFade: Frame? = nil
local detail: Frame? = nil
local caseFrame: Frame? = nil
local viewport: ViewportFrame? = nil
local viewportCamera: Camera? = nil
local viewportModel: Model? = nil
local viewportId: string? = nil
local viewportBuiltAt = -math.huge
local pictureCentre = Vector3.zero
local pictureSize = Vector3.one
local screenWas = Vector2.zero
local menu: { { id: string, row: TextButton } } = {}
local cards: { { id: string, card: TextButton } } = {}
local shelves: { TextLabel } = {}
local eyebrowLabel: TextLabel? = nil
local nameLabel: TextLabel? = nil
local priceLabel: TextLabel? = nil
local priceCaption: TextLabel? = nil
local priceCoin: Frame? = nil
local ruleLine: Frame? = nil
local blurbLabel: TextLabel? = nil
local statusDot: Frame? = nil
local statusLabel: TextLabel? = nil
local buyButton: TextButton? = nil
local buyWord: TextLabel? = nil
local buyAmount: TextLabel? = nil
local buyCoin: Frame? = nil
local buyDivider: Frame? = nil
local buyGradient: UIGradient? = nil
local buyStroke: UIStroke? = nil
local buyHighlight: Frame? = nil
local buyTick: Frame? = nil
local buyProgress: Frame? = nil
local buyProgressFill: Frame? = nil
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
	-- TASK 229: a press this panel sent on, and a press it refused (an unusable control, or no
	-- sender wired). `layouts` above is what proves the owned row's HEIGHT is written once per
	-- CHANGE and not once per render.
	roleSent = 0,
	roleBlocked = 0,
}

function ShopPanel.stats()
	return table.clone(stats)
end

-- DOES THE HUD'S RIGHT-EDGE RAIL HAVE TO GET OUT OF THE WAY? (task 196 part 3f.) On a phone the
-- panel is the whole screen, so the MAP and REPORT buttons sit ON TOP of it -- the Director read
-- that off the 400-wide frame.
--
-- THE SHOP ASKS AND THE HUD HIDES, because the rail is the Hud's (`Hud.Rail` owns every button in
-- it) and this module must not reach into another owner's frame. PURE, so a spec can ask it at any
-- width without a screen.
function ShopPanel.hidesRail(screenWidth: number): boolean
	return open and screenWidth < ShopData.CONFIG.PANEL.WIDE_AT
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

-- THE WALLET, as the two numbers it really is: the pills carry their own captions, so there is no
-- sentence to format any more (`TEXT.BALANCE` is gone).
function ShopPanel.walletText(): string
	return string.format(
		"%s|%s",
		if coinsValue then coinsValue.Text else "",
		if huntsValue then huntsValue.Text else ""
	)
end

function ShopPanel.statusText(): string
	return if statusLabel then statusLabel.Text else ""
end

function ShopPanel.lastState(): any
	return payload
end

function ShopPanel.selectedId(): string?
	return selected
end

-- WHAT IS ACTUALLY ON SCREEN, row by row -- `ReportPanel.rowText`'s rule: the seam a client spec
-- reads instead of guessing. `NAME|PRICE|TAG`, which is the three things a row says.
function ShopPanel.rowText(): { string }
	local out = {}
	for _, entry in ipairs(menu) do
		if entry.row.Visible then
			local name = entry.row:FindFirstChild("Name")
			local price = entry.row:FindFirstChild("Price")
			local tag = entry.row:FindFirstChild("Tag")
			local tagText = if tag then tag:FindFirstChild("TagText") else nil
			table.insert(
				out,
				string.format(
					"%s|%s|%s",
					if name and name:IsA("TextLabel") then name.Text else "",
					if price and price:IsA("TextLabel") then price.Text else "",
					if tag
							and (tag :: GuiObject).Visible
							and tagText
							and tagText:IsA("TextLabel")
						then tagText.Text
						else ""
				)
			)
		end
	end
	return out
end

-- THE SAME THREE THINGS OFF THE PHONE'S CARDS, so the stacked layout is read rather than assumed.
function ShopPanel.cardText(): { string }
	local out = {}
	for _, entry in ipairs(cards) do
		local name = entry.card:FindFirstChild("Name")
		local price = entry.card:FindFirstChild("Price")
		local tag = entry.card:FindFirstChild("Tag")
		local tagText = if tag then tag:FindFirstChild("TagText") else nil
		table.insert(
			out,
			string.format(
				"%s|%s|%s",
				if name and name:IsA("TextLabel") then name.Text else "",
				if price and price:IsA("TextLabel") then price.Text else "",
				if tag and (tag :: GuiObject).Visible and tagText and tagText:IsA("TextLabel") then tagText.Text else ""
			)
		)
	end
	return out
end

-- THE SHELF LABELS ON SCREEN, in order.
function ShopPanel.headerText(): { string }
	local out = {}
	for _, shelf in ipairs(shelves) do
		if shelf.Visible then
			table.insert(out, shelf.Text)
		end
	end
	return out
end

-- WHAT THE DETAIL COLUMN SAYS, as seven strings. One seam for the whole page, so a spec reads the
-- screen rather than the payload it just handed in.
export type Detail = {
	eyebrow: string,
	name: string,
	price: string,
	blurb: string,
	status: string,
	button: string,
	amount: string,
}

function ShopPanel.detailText(): Detail
	return {
		eyebrow = if eyebrowLabel then eyebrowLabel.Text else "",
		name = if nameLabel then nameLabel.Text else "",
		price = if priceLabel then priceLabel.Text else "",
		blurb = if blurbLabel then blurbLabel.Text else "",
		status = if statusLabel then statusLabel.Text else "",
		button = if buyWord then buyWord.Text else "",
		amount = if buyAmount and buyAmount.Visible then buyAmount.Text else "",
	}
end

function ShopPanel.pictureId(): string?
	return viewportId
end

function ShopPanel.pictureModel(): Model?
	return viewportModel
end

function ShopPanel.viewportFrame(): ViewportFrame?
	return viewport
end

-- THE BOX THE PICTURE'S CAMERA IS AIMED AT: the model's own bounding centre and size, measured once
-- when the picture was built. Exported because the camera is aimed AT THE BOX CENTRE and not at the
-- model's pivot, so a spec checking where the lens points has to be told which point to check.
function ShopPanel.pictureBall(): (Vector3, Vector3)
	return pictureCentre, pictureSize
end

-- ---------------------------------------------------------------- the rectangle, pure
--
-- THE WHOLE LAYOUT AS ARITHMETIC (task 165's rule: *"asserted ARITHMETICALLY rather than by a
-- screenshot"*). PURE: a screen size in, every rectangle out, nothing read and nothing written. It
-- is what `Hud.build` sizes the frame with, what `relayout` writes, and what the client spec drives
-- at 1280 x 720 and 400 x 800.
--
-- THE SPEC'S OWN TABLE, READ AS DELTAS. Section 3.3 lists absolute y values for the wide panel and
-- 3.4 for the phone; the gaps between them are identical, so one arithmetic answers both and the
-- two modes cannot drift apart.
export type Layout = {
	mode: string,
	width: number,
	height: number,
	headerHeight: number,
	wellX: number,
	wellY: number,
	wellWidth: number,
	wellHeight: number,
	rowWidth: number,
	rowHeight: number,
	stripY: number,
	stripHeight: number,
	cardWidth: number,
	detailX: number,
	detailY: number,
	detailWidth: number,
	detailHeight: number,
	caseX: number,
	caseY: number,
	caseWidth: number,
	caseHeight: number,
	eyebrowY: number,
	nameY: number,
	priceY: number,
	ruleY: number,
	blurbY: number,
	blurbHeight: number,
	blurbLines: number,
	statusY: number,
	buttonY: number,
	buttonHeight: number,
	-- THE ROLE SWITCH (task 229): "row" in WIDE, "detail" in TALL, "none" when he does not own
	-- `ALWAYS HUNTER`. `switchRowHeight` is `ROW_SWITCH_PX` for the one owned row and `ROW_PX` for
	-- every other; `switchBlock` is the 70 px the detail pane's status row becomes on a phone.
	switchSurface: string,
	switchRowHeight: number,
	switchBlock: number,
	switchTrackWidth: number,
	switchHalfWidth: number,
}

-- WHERE THE ROLE SWITCH GOES (task 229). PURE, and it is ONE rule rather than a convention: *"the
-- switch appears once, on whichever surface the item has. WIDE -> the row. TALL -> the detail pane.
-- **Never both.**"* (the Designer's spec section 3.5). A function can be asserted; a convention
-- cannot.
--
--   "row"    WIDE, and he owns it: the one `ALWAYS HUNTER` row is built 124 tall instead of 64
--   "detail" TALL, he owns it, AND that row is the SELECTED item -- the 108 px card has no room,
--            so on a phone the switch rides the detail pane's status block
--   "none"   he does not own it (the attribute is absent), so nothing is drawn anywhere
function ShopPanel.switchSurfaceFor(mode: string, wish: string?, id: string?): string
	if wish ~= ShopPanel.ROLE.HUNTER and wish ~= ShopPanel.ROLE.BEATER then
		return "none"
	end
	if mode == "WIDE" then
		return "row"
	end
	return if id == ShopData.ITEM.ALWAYS_HUNTER then "detail" else "none"
end

function ShopPanel.layoutFor(screenWidth: number, screenHeight: number, surface: string?): Layout
	local margin = PANEL.MARGIN
	local width = math.clamp(screenWidth - 2 * margin, PANEL.MIN_WIDTH, PANEL.MAX_WIDTH)
	local height = math.clamp(math.floor(screenHeight * PANEL.HEIGHT_FRACTION), PANEL.MIN_HEIGHT, PANEL.MAX_HEIGHT)
	local wide = width >= PANEL.WIDE_AT

	-- THE TWO COLUMNS, or the one. In WIDE the well is a fixed 228 and the detail column takes the
	-- rest; in TALL the strip is the full width and the detail column is the panel less its gutters.
	local wellWidth = PANEL.WELL_WIDTH
	local detailX = if wide then PANEL.WELL_X + wellWidth + PANEL.DETAIL_GAP else margin + 4
	local detailY = if wide then PANEL.HEADER_PX else PANEL.STRIP_Y + PANEL.STRIP_PX + 10
	local detailWidth = width - detailX - (if wide then PANEL.DETAIL_GAP else margin + 4)
	local detailHeight = height - detailY - PANEL.BOTTOM_PX

	-- THE STACK, FROM THE BOTTOM UP: the button is pinned to the bottom of the column, the status
	-- line sits 26 px above it, and the case takes what is left between the top and the blurb's
	-- three lines -- which is the spec's *"the blurb box absorbs the remainder"* read the other way
	-- round, and the floor under the case is the spec's 110.
	local buttonY = detailY + detailHeight - PANEL.BUTTON_PX
	-- THE STATUS ROW BECOMES THE SWITCH BLOCK ON A PHONE (task 229, spec 3.5): 70 px instead of 14,
	-- sitting directly above the `OWNED` button, and *"the blurb box absorbs the difference, exactly
	-- as `layoutFor` already absorbs everything else"* -- which is the `room` subtraction below,
	-- unchanged, because `statusY` is what it reads.
	local block = if surface == "detail" then PANEL.DETAIL_SWITCH_PX else 0
	local statusY = buttonY - PANEL.STATUS_GAP - block
	local below = PANEL.EYEBROW_GAP + PANEL.NAME_GAP + PANEL.PRICE_GAP + PANEL.RULE_GAP + PANEL.BLURB_GAP
	local minBlurb = 3 * PANEL.LINE_PX
	local wanted = if wide then PANEL.CASE_WIDE_PX else PANEL.CASE_TALL_PX
	local room = (statusY - PANEL.EYEBROW_GAP) - detailY - below - minBlurb
	local caseHeight = math.floor(math.clamp(math.min(wanted, room), PANEL.CASE_MIN_PX, wanted))

	-- THE TRACK'S WIDTH ON WHICHEVER SURFACE IT IS ON: the row less its two insets in WIDE
	-- (`rowWidth - 14 - 12` = 186 at 1280 x 720, the Designer's own number), the detail column less
	-- nothing in TALL -- the pane is already inset.
	local trackWidth = if surface == "detail"
		then detailWidth
		else (wellWidth - 2 * PANEL.WELL_PAD) - PANEL.SWITCH_LEFT - PANEL.SWITCH_RIGHT
	local caseY = detailY
	local eyebrowY = caseY + caseHeight + PANEL.EYEBROW_GAP
	local nameY = eyebrowY + PANEL.NAME_GAP
	local priceY = nameY + PANEL.PRICE_GAP
	local ruleY = priceY + PANEL.RULE_GAP
	local blurbY = ruleY + PANEL.BLURB_GAP
	local blurbHeight = math.max(statusY - PANEL.EYEBROW_GAP - blurbY, PANEL.LINE_PX)

	return {
		mode = if wide then "WIDE" else "TALL",
		width = width,
		height = height,
		headerHeight = PANEL.HEADER_PX,
		wellX = PANEL.WELL_X,
		wellY = PANEL.WELL_Y,
		wellWidth = wellWidth,
		wellHeight = height - PANEL.WELL_Y - PANEL.WELL_BOTTOM,
		rowWidth = wellWidth - 2 * PANEL.WELL_PAD,
		rowHeight = PANEL.ROW_PX,
		stripY = PANEL.STRIP_Y,
		stripHeight = PANEL.STRIP_PX,
		cardWidth = PANEL.CARD_WIDTH,
		detailX = detailX,
		detailY = detailY,
		detailWidth = detailWidth,
		detailHeight = detailHeight,
		caseX = detailX,
		caseY = caseY,
		caseWidth = detailWidth,
		caseHeight = caseHeight,
		eyebrowY = eyebrowY,
		nameY = nameY,
		priceY = priceY,
		ruleY = ruleY,
		blurbY = blurbY,
		blurbHeight = blurbHeight,
		-- HOW MANY LINES OF THE EXPLANATION FIT, which is the number `Shop.CONFIG.PANEL.BLURB_MAX`
		-- is measured against -- and the client spec asserts the PHONE still holds three.
		blurbLines = math.floor(blurbHeight / PANEL.LINE_PX),
		statusY = statusY,
		buttonY = buttonY,
		buttonHeight = PANEL.BUTTON_PX,
		-- TASK 229. `surface` nil answers exactly today's layout, so every existing caller --
		-- `Hud.build`'s `panelSize`, every spec that calls `layoutFor(w, h)` -- is unchanged by
		-- construction.
		switchSurface = surface or "none",
		switchRowHeight = if surface == "row" then PANEL.ROW_SWITCH_PX else PANEL.ROW_PX,
		switchBlock = block,
		switchTrackWidth = trackWidth,
		-- `(track - 2*PAD - GAP) / 2`: the formula, not the Designer's drawing, which forgot the
		-- 3 px between the halves (`Shop.CONFIG.PANEL.ROLE_SWITCH`).
		switchHalfWidth = (trackWidth - 2 * ROLE.TRACK_PAD - ROLE.TRACK_GAP) / 2,
	}
end

-- THE SCREEN THIS CLIENT HAS, or the phone-sized default when there is no camera to ask. THE
-- DEFAULT IS THE SMALL ONE on purpose: a layout that guessed big would overflow a phone, and one
-- that guesses small only wastes pixels until the next frame.
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

-- WHAT `Hud.build` SIZES THE FRAME WITH -- one function decides the box, and from `build` onward
-- this module is the only writer of it.
function ShopPanel.panelSize(): UDim2
	local size = screenSize()
	local layout = ShopPanel.layoutFor(size.X, size.Y)
	return UDim2.fromOffset(layout.width, layout.height)
end

-- ---------------------------------------------------------------- small makers

local function corner(instance: Instance, radius: number): UICorner
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, radius)
	round.Parent = instance
	return round
end

local function stroke(instance: Instance, color: Color3, transparency: number?): UIStroke
	local line = Instance.new("UIStroke")
	line.Thickness = 1
	line.Color = color
	line.Transparency = transparency or 0
	line.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	line.Parent = instance
	return line
end

local function frame(parent: Instance, name: string, zOffset: number): Frame
	local made = Instance.new("Frame")
	made.Name = name
	made.BorderSizePixel = 0
	made.BackgroundColor3 = LOOK.PANEL
	made.ZIndex = Z + zOffset
	made.Parent = parent
	return made
end

-- EVERY CHILD SITS ABOVE THE PANEL'S OWN ZINDEX, and task 124's measured defect is why: with the
-- panel opaque at ZIndex 10 and its labels at the default 1, a whole report came out as an EMPTY
-- BLACK RECTANGLE -- the text was being drawn BEHIND its own background.
local function label(
	parent: Instance,
	name: string,
	font: Font,
	size: number,
	color: Color3,
	zOffset: number
): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.FontFace = font
	text.TextSize = size
	text.TextColor3 = color
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.Text = ""
	text.ZIndex = Z + zOffset
	text.Parent = parent
	return text
end

-- THE BRASS COIN, as a Frame: a disc with a lit top-left and a dark rim (spec 3.2). No ImageLabel
-- anywhere in this panel, and no glyph: *"icons are Frames"*.
local function coin(parent: Instance, name: string, diameter: number, zOffset: number): Frame
	local disc = frame(parent, name, zOffset)
	disc.Size = UDim2.fromOffset(diameter, diameter)
	disc.BackgroundColor3 = LOOK.BRASS
	corner(disc, math.floor(diameter / 2))
	local shine = Instance.new("UIGradient")
	shine.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, LOOK.BRASS_HI),
		ColorSequenceKeypoint.new(0.5, LOOK.BRASS),
		ColorSequenceKeypoint.new(1, LOOK.BRASS_LO),
	})
	shine.Rotation = 55
	shine.Parent = disc
	stroke(disc, Color3.fromHex("6E5526"))
	return disc
end

local function verticalGradient(instance: Instance, colors: ColorSequence): UIGradient
	local paint = Instance.new("UIGradient")
	paint.Color = colors
	paint.Rotation = 90
	paint.Parent = instance
	return paint
end

-- ---------------------------------------------------------------- the two-way switch (task 229)
--
-- KAREN, 2026-10-21: *"we also need to have posibility to choose once you have a card always hunter
-- maybe sometimes I want to be a beater we need to find a way to do that"*.
--
-- THE CONTROL IS BUILT AND PAINTED HERE, AND PLACED BY WHOEVER OWNS THE RECTANGLE IT SITS IN. It is
-- drawn on two surfaces -- this panel's owned `ALWAYS HUNTER` row and `Hud.PadPanel`'s truck-pad
-- dialog -- and *"The shop sets the house style. Anything built after it follows these"* (the
-- Designer's spec section 8) is why the two of them are ONE control and not two. `PadPanel` already
-- requires this module for `LOOK`, `FONT` and `spaced`, so there is no new require edge and no
-- cycle; what each panel keeps is its own `relayout`, which stays the one writer of every rectangle
-- it owns.
--
-- A SEGMENTED SWITCH AND NOT A CHECKBOX (spec 3.3): the two sides are equal and both have to be
-- NAMED, because a checkbox would read *"be a beater?"* and make HUNTER the absence of something --
-- and HUNTER is the thing he bought.
--
-- NOTHING SLIDES. There is no travelling thumb (`design-system.md` section 1.4 -- *"A HUD that moves
-- is a HUD you cannot read while aiming"*): the selected half simply IS the lit one, and the 2 px
-- underline at full opacity is the only chrome the control has, because it is what makes "selected"
-- crisp on a slab tinted to 0.80.
export type RoleSwitch = {
	track: Frame,
	halves: { [string]: TextButton },
	words: { [string]: TextLabel },
	bars: { [string]: Frame },
	rims: { [string]: UIStroke },
	selected: string?,
	hovered: string?,
	usable: boolean?,
}

-- THE TWO WORDS, AND THEY ARE `ReplicatedStorage.Lobby`'S (`Lobby.ROLE_WISH`): the server writes one
-- of them into the attribute both panels read, so there is one spelling of "beater" in the
-- repository and a typo cannot make a switch that never lights.
ShopPanel.ROLE = LobbyData.ROLE_WISH
-- ...AND THE CONTROL'S GEOMETRY, re-exported for `Hud.PadPanel` beside `LOOK`, `FONT` and `spaced`:
-- it is the house style, so the other surface reads it from here rather than keeping a second copy.
ShopPanel.ROLE_SWITCH = ROLE

local function roleColour(role: string): Color3
	return if role == ShopPanel.ROLE.BEATER then LOOK.BEATER else LOOK.HUNTER
end

-- THE INSTANCES, BUILT ONCE. `words` carries the label to write, `zLift` the band to sit in, and
-- `onPress` the one thing a press does -- which is never "decide": it ASKS, and the server answers
-- by writing the attribute both panels are told.
function ShopPanel.buildRoleSwitch(
	parent: Instance,
	zLift: number,
	wordSize: number,
	words: { [string]: string },
	onPress: (string) -> ()
): RoleSwitch
	local track = frame(parent, "RoleSwitch", zLift)
	track.BackgroundColor3 = LOOK.SLATE
	track.Visible = false
	corner(track, ROLE.TRACK_CORNER)
	stroke(track, LOOK.LINE, 0)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, ROLE.TRACK_PAD)
	pad.PaddingBottom = UDim.new(0, ROLE.TRACK_PAD)
	pad.PaddingLeft = UDim.new(0, ROLE.TRACK_PAD)
	pad.PaddingRight = UDim.new(0, ROLE.TRACK_PAD)
	pad.Parent = track
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Padding = UDim.new(0, ROLE.TRACK_GAP)
	row.Parent = track

	local out: RoleSwitch = {
		track = track,
		halves = {},
		words = {},
		bars = {},
		rims = {},
		selected = nil,
		hovered = nil,
		usable = true,
	}
	for order, which in ipairs({ ShopPanel.ROLE.HUNTER, ShopPanel.ROLE.BEATER }) do
		local half = Instance.new("TextButton")
		half.Name = if which == ShopPanel.ROLE.BEATER then "Beater" else "Hunter"
		half.AutoButtonColor = false
		-- THE HALF CARRIES NO TEXT OF ITS OWN: the word is a centred child label, which is this
		-- panel's own big-button arrangement and the only way to set a face, a size and a letter
		-- spacing in one control.
		half.Text = ""
		half.BackgroundColor3 = roleColour(which)
		half.BackgroundTransparency = 1
		half.BorderSizePixel = 0
		half.LayoutOrder = order
		-- HALF THE PADDED INTERIOR, LESS HALF THE ONE GAP BETWEEN THEM, as a SCALE -- so the two
		-- halves and their gap exactly fill whatever width the owner's `relayout` gives the track,
		-- at every screen size, with no second copy of the arithmetic.
		--
		-- **The Designer's drawing says 141 x 32 for a 288-wide track and the formula beside it says
		-- `(track - 9) / 2` = 139.5: the drawing forgot the 3 px between the halves. The FORMULA is
		-- what is built, because it is the one that adds up** -- and `PadPanel.layoutFor` reports
		-- the same number so a spec asserts the arithmetic rather than the picture.
		half.Size = UDim2.new(0.5, -ROLE.TRACK_GAP / 2, 1, 0)
		-- ABOVE THE BLOCK'S OWN LABELS, so Roblox routes a press to the half and not to what is
		-- under it. In the shop's row that is the whole point, because the row is a `TextButton` too.
		half.ZIndex = Z + zLift + 2
		half.ClipsDescendants = true
		corner(half, ROLE.HALF_CORNER)
		local rim = stroke(half, roleColour(which), 1)
		rim.Name = "Rim"
		local word = label(half, "Word", SANS_BOLD, wordSize, LOOK.MUTED, zLift + 3)
		word.Size = UDim2.fromScale(1, 1)
		word.TextXAlignment = Enum.TextXAlignment.Center
		word.TextYAlignment = Enum.TextYAlignment.Center
		word.Text = spaced(words[which] or "")
		-- THE 2 px UNDERLINE at the half's bottom inside edge, inset each side (spec 3.3).
		local bar = frame(half, "Underline", zLift + 3)
		bar.AnchorPoint = Vector2.new(0.5, 1)
		bar.Position = UDim2.fromScale(0.5, 1)
		bar.Size = UDim2.new(1, -2 * ROLE.UNDERLINE_INSET, 0, ROLE.UNDERLINE_PX)
		bar.BackgroundColor3 = roleColour(which)
		bar.Visible = false
		corner(bar, 1)
		half.Parent = track
		out.halves[which] = half
		out.words[which] = word
		out.bars[which] = bar
		out.rims[which] = rim
		-- THE WORD IS CLOSED OVER AND NOTHING ELSE IS, so a control redrawn for another state cannot
		-- ask for the half it used to show (`buildWell`'s own rule for a row's id).
		half.Activated:Connect(function()
			-- THE PRESS TINT, AND IT IS THE ONLY THING A PRESS DRAWS. `paintRoleSwitch` puts the
			-- half back the moment the server's word arrives, or on the next repaint if it never
			-- does -- so this can never become a second opinion about which half is lit.
			if out.usable ~= false then
				half.BackgroundColor3 = roleColour(which)
				half.BackgroundTransparency = ROLE.PRESS_TRANSPARENCY
				task.delay(ROLE.TWEEN_SECONDS, function()
					if half.Parent ~= nil then
						ShopPanel.paintRoleSwitch(out, out.selected, out.usable)
					end
				end)
			end
			onPress(which)
		end)
		-- `MouseEnter` / `MouseLeave` fire for a mouse and never for a finger, which is right: a
		-- finger has no hover.
		half.MouseEnter:Connect(function()
			if out.hovered ~= which then
				out.hovered = which
				ShopPanel.paintRoleSwitch(out, out.selected, out.usable)
			end
		end)
		half.MouseLeave:Connect(function()
			if out.hovered == which then
				out.hovered = nil
				ShopPanel.paintRoleSwitch(out, out.selected, out.usable)
			end
		end)
	end
	return out
end

-- WHICH HALF IS LIT, AND WHETHER EITHER MAY BE PRESSED. The ONE painter, so the two surfaces cannot
-- disagree about what "selected" looks like.
--
-- 0.12 s ON `BackgroundColor3` AND `TextColor3` ONLY (spec 3.3). The transparencies, the rim and the
-- underline are written directly: a tween on a transparency would make the control FADE rather than
-- change, and nothing here animates a position at all.
function ShopPanel.paintRoleSwitch(switch: RoleSwitch, lit: string?, usable: boolean?)
	switch.selected = lit
	switch.usable = usable ~= false
	local dim = usable == false
	switch.track.BackgroundTransparency = if dim then ROLE.DIM_TRANSPARENCY else 0
	for which, half in pairs(switch.halves) do
		local on = which == lit
		local hover = (not dim) and switch.hovered == which and not on
		local colour = if on and not dim then roleColour(which) else LOOK.ROW_HOVER
		local wordColour = if dim
			then LOOK.FAINT
			else (if on then roleColour(which) else (if hover then LOOK.BODY else LOOK.MUTED))
		half.BackgroundTransparency = if on
			then (if dim then ROLE.DIM_TRANSPARENCY else ROLE.FILL_TRANSPARENCY)
			else (if hover then 0 else 1)
		switch.rims[which].Transparency = if on and not dim then ROLE.STROKE_TRANSPARENCY else 1
		switch.bars[which].Visible = on and not dim
		local word = switch.words[which]
		local tween = TweenInfo.new(ROLE.TWEEN_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		if half.BackgroundColor3 ~= colour then
			TweenService:Create(half, tween, { BackgroundColor3 = colour }):Play()
		end
		if word.TextColor3 ~= wordColour then
			TweenService:Create(word, tween, { TextColor3 = wordColour }):Play()
		end
	end
end

-- ---------------------------------------------------------------- the words, pure and exported
--
-- PURE and exported for `ReportPanel.listRowText`'s reason: what the panel SAYS has to be a spec
-- rather than a screenshot.

function ShopPanel.rowNameFor(row: any): string
	return if row == nil then "" else tostring(row.label)
end

function ShopPanel.rowPriceFor(row: any): string
	-- `Money.text` (task 221): one formatter, so the price the window prints and the number the
	-- till charges are the same string rule.
	return if row == nil then "" else Money.text(row.price)
end

-- THE TAG A ROW WEARS, and the kind of thing it is. A row answers *"can I buy this?"* without being
-- clicked (spec 0.3), and the affordability signal is never colour alone: a row you cannot afford
-- says SHORT with the number on it.
--
-- `hunts` IS THE WALLET'S OWN NUMBER, passed in rather than read, because a tag like `12 / 25` is
-- the only place in the panel where the row and the wallet are both on screen at once.
function ShopPanel.tagFor(row: any, hunts: number?): (string, string)
	if row == nil then
		return "", "none"
	end
	if row.owned == true then
		return TEXT.OWNED_TAG, "owned"
	end
	if row.sale ~= true then
		return TEXT.SOON_TAG, "soon"
	end
	if row.locked == true then
		return string.format(TEXT.ROW_LOCK_TAG, math.max(hunts or 0, 0), row.hunts), "locked"
	end
	if row.afford ~= true then
		return "", "poor"
	end
	return "", "none"
end

-- THE TAG'S TEXT ALONE, with the shortfall filled in for a row the player cannot afford: that
-- number is the balance's business and `render` holds both.
function ShopPanel.tagTextFor(row: any, hunts: number?, balance: number?): (string, string)
	local text, kind = ShopPanel.tagFor(row, hunts)
	if kind == "poor" then
		return string.format(TEXT.ROW_POOR_TAG, Money.text(math.max(row.price - (balance or 0), 0))), kind
	end
	return text, kind
end

-- THE ONE BIG BUTTON'S STATE, decided once and drawn in one place (spec 4). `buyable` is the ONE
-- field the "may he press it" question reads -- computed on the SERVER -- so a live button and an
-- accepted purchase cannot disagree (design hazard 10).
export type ButtonState = { kind: string, word: string, amount: string?, progress: number? }

function ShopPanel.buttonStateFor(row: any, hunts: number?, balance: number?): ButtonState
	if row == nil then
		return { kind = "none", word = TEXT.PICK }
	end
	if row.buyable == true then
		return { kind = "buy", word = TEXT.BUY, amount = Money.text(row.price) }
	end
	if row.owned == true then
		return { kind = "owned", word = TEXT.OWNED_BUTTON }
	end
	if row.sale ~= true then
		return { kind = "soon", word = TEXT.SOON_TAG }
	end
	if row.locked == true then
		local walked = math.max(hunts or 0, 0)
		local left = math.max(row.hunts - walked, 0)
		return {
			kind = "locked",
			word = string.format(TEXT.LOCKED_BUTTON, left),
			-- THE LOCKED BUTTON CARRIES THE PROGRESS, drawn rather than written twice: that is why
			-- the item is locked (spec 4).
			progress = if row.hunts > 0 then math.clamp(walked / row.hunts, 0, 1) else 1,
		}
	end
	return { kind = "poor", word = string.format(TEXT.POOR_BUTTON, Money.text(math.max(row.price - (balance or 0), 0))) }
end

-- THE WALLET'S TWO NUMBERS. `--` AND NOT `0` for a player with no open profile, which is
-- `Economy.balanceOf`'s own rule: nil is not the same fact as a balance of zero.
-- WHAT THE SWITCH'S CAPTION SAYS ON THIS SURFACE, or "" when there is no switch. PURE, two rows and
-- a receipt, out of `Shop.CONFIG.TEXT` so the words are Karen's to rewrite (task 229).
--
-- THE SHOP HAS NO PAD AND NO PARTY SIZE, so it can never say `NO BEATERS THIS DRIVE` -- that row
-- exists in both tables because the two are one vocabulary, and a reader comparing them should find
-- no gap.
function ShopPanel.roleCaptionFor(wish: string?, side: string?): string
	if wish ~= ShopPanel.ROLE.HUNTER and wish ~= ShopPanel.ROLE.BEATER then
		return ""
	end
	if side ~= nil then
		return TEXT.ROLE_ASKED
	end
	return if wish == ShopPanel.ROLE.BEATER then TEXT.ROLE_BEATING else TEXT.ROLE_HUNTING
end

-- MAY EITHER HALF BE PRESSED? PURE. False in exactly the state the caption explains, so the dimming
-- and the words can never disagree: once the drive has given him a side the ask is in.
function ShopPanel.roleUsable(wish: string?, side: string?): boolean
	return (wish == ShopPanel.ROLE.HUNTER or wish == ShopPanel.ROLE.BEATER) and side == nil
end

function ShopPanel.coinsTextFor(state: any): string
	-- `Money.text` ANSWERS BOTH HALVES (task 221): "$1240" for a number and `Money.UNKNOWN` for a
	-- nil, which is the `--` this function used to write out by hand.
	return Money.text(state and state.balance)
end

function ShopPanel.huntsTextFor(state: any): string
	local hunts = state and state.hunts
	return if type(hunts) == "number" then string.format("%d", hunts) else "--"
end

-- WHAT THE STATUS LINE SAYS: the last receipt or refusal for as long as `MESSAGE_SECONDS`, and
-- otherwise the one caveat. PURE in its inputs so a spec can drive the expiry with a number.
function ShopPanel.statusFor(line: string?, at: number, now: number): string
	if line ~= nil and now - at <= LOOK.MESSAGE_SECONDS then
		return line
	end
	return TEXT.HINT
end

-- ...AND ITS COLOUR: faint for the caveat, green for the receipt, clay for the refusal (spec 4).
function ShopPanel.statusColorFor(line: string?, kind: string?, at: number, now: number): Color3
	if line == nil or now - at > LOOK.MESSAGE_SECONDS then
		return LOOK.FAINT
	end
	if kind == "bought" then
		return LOOK.PINE_TEXT
	end
	return LOOK.CLAY
end

-- ---------------------------------------------------------------- what is selected

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

-- WHICH ITEM A FRESHLY OPENED PANEL SHOWS: THE FIRST ONE HE MAY ACTUALLY BUY, and the first row in
-- the menu when there is no such thing. The first frame of task 196 is why (rule 5): the menu's
-- order puts WEAPONS first, and a shop that opens on a page headed SOON or LOCKED is a shop that
-- opens on a refusal.
local function firstId(): string?
	local order = ShopData.menuOrder((payload and payload.rows) or nil)
	for _, id in ipairs(order) do
		local row = ShopPanel.rowFor(id)
		if row ~= nil and row.buyable == true then
			return id
		end
	end
	if #order > 0 then
		return order[1]
	end
	return if #menu > 0 then menu[1].id else nil
end

-- ---------------------------------------------------------------- the picture

function ShopPanel.showPicture(id: string?)
	local box = viewport
	if box == nil then
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
	model.Parent = box
	viewportModel = model
	viewportId = id
	pictureCentre, pictureSize = ShopDisplay.frameOf(model)
	viewportBuiltAt = os.clock()
	stats.pictures += 1
	ShopPanel.aim(0)
end

-- WHERE THE VIEWPORT'S CAMERA IS AT THIS ANGLE. The framing is `ShopDisplay`'s pure arithmetic and
-- this is the one line that writes it.
function ShopPanel.aim(angleDeg: number)
	local camera = viewportCamera
	if camera == nil or viewportModel == nil or viewport == nil then
		return
	end
	local box = (viewport :: ViewportFrame).AbsoluteSize
	local aspect = if box.X > 1 and box.Y > 1 then box.X / box.Y else 16 / 9
	camera.CFrame =
		ShopDisplay.cameraCFrame(pictureCentre, pictureSize, angleDeg, ShopDisplay.viewFor(viewportId), aspect)
end

-- ONE STEP OF THE TURN, called by `Hud.renderObjective` -- the Hud's one per-frame evaluation. NO
-- SECOND LOOP: a module with a `RenderStepped` connection of its own would be a second owner of
-- this client's frame. It writes one `CFrame` a frame while the panel is open and nothing at all
-- while it is shut, which is every frame of a hunt.
--
-- THE SCREEN IS MEASURED OPEN OR SHUT, and the first frame of task 196 is why: `Hud.build` sizes
-- this panel before anything has been rendered, when `ViewportSize` is not the screen yet.
function ShopPanel.step(now: number?)
	if screenSize() ~= screenWas then
		ShopPanel.relayout()
	end
	if not open or viewportModel == nil then
		return
	end
	local clock = now or os.clock()
	-- WHERE A LATE MESH LANDS: the rifle's meshes are only downloaded when something asks for them,
	-- and a player who has only ever carried the shotgun has never asked. Task 133's
	-- stale-and-rebuild path, once a second until the real gun is in the case.
	if ShopDisplay.rebuildWanted() and clock - viewportBuiltAt >= 1 then
		ShopPanel.showPicture(viewportId)
	end
	ShopPanel.aim(ShopDisplay.spinDegAt(clock, ShopDisplay.viewFor(viewportId)))
end

-- ---------------------------------------------------------------- building: the header

local function buildHeader(root: Frame)
	local bar = frame(root, "Header", 1)
	bar.BackgroundColor3 = LOOK.HEADER_TOP
	bar.Position = UDim2.new()
	corner(bar, PANEL.CORNER)
	verticalGradient(
		bar,
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, LOOK.HEADER_TOP),
			ColorSequenceKeypoint.new(1, LOOK.HEADER_BOTTOM),
		})
	)
	-- THE CORNER IS ROUND AT THE TOP AND SQUARE AT THE BOTTOM, and Roblox has no per-corner radius:
	-- a second Frame fills the bottom half of the round corners.
	local foot = frame(bar, "HeaderFoot", 1)
	foot.BackgroundColor3 = LOOK.HEADER_BOTTOM
	foot.AnchorPoint = Vector2.new(0, 1)
	foot.Position = UDim2.fromScale(0, 1)
	foot.Size = UDim2.new(1, 0, 0, PANEL.CORNER)

	-- ONE BRASS HAIRLINE SEPARATES A HEADER FROM A BODY, and never two (spec 8.2). It fades out at
	-- both ends, which is what stops it reading as a box.
	local hair = frame(root, "HeaderRule", 2)
	hair.BackgroundColor3 = LOOK.BRASS
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.12, 0.58),
		NumberSequenceKeypoint.new(0.88, 0.58),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = hair

	local eyebrow = label(root, "Eyebrow", SANS_SEMI, 9, LOOK.BRASS, 3)
	eyebrow.Text = spaced(TEXT.EYEBROW)
	title = label(root, "Title", OSWALD_SB, 23, LOOK.PAPER, 3);
	(title :: TextLabel).Text = TEXT.TITLE

	-- THE WALLET: two pills, each an icon, a number and a caption. The caption is what lets the
	-- numbers be numbers -- there is no sentence to format any more.
	local wallet = frame(root, "Wallet", 2)
	wallet.BackgroundTransparency = 1
	wallet.AnchorPoint = Vector2.new(1, 0)
	local walletRow = Instance.new("UIListLayout")
	walletRow.FillDirection = Enum.FillDirection.Horizontal
	walletRow.HorizontalAlignment = Enum.HorizontalAlignment.Right
	walletRow.VerticalAlignment = Enum.VerticalAlignment.Center
	walletRow.SortOrder = Enum.SortOrder.LayoutOrder
	walletRow.Padding = UDim.new(0, 8)
	walletRow.Parent = wallet

	local function pill(name: string, order: number): (Frame, TextLabel)
		local box = frame(wallet, name, 3)
		box.BackgroundColor3 = Color3.fromHex("221E18")
		box.LayoutOrder = order
		box.AutomaticSize = Enum.AutomaticSize.X
		corner(box, 10)
		stroke(box, LOOK.LINE)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 12)
		pad.Parent = box
		local row = Instance.new("UIListLayout")
		row.FillDirection = Enum.FillDirection.Horizontal
		row.VerticalAlignment = Enum.VerticalAlignment.Center
		row.SortOrder = Enum.SortOrder.LayoutOrder
		row.Padding = UDim.new(0, 7)
		row.Parent = box
		local value = label(box, "Value", OSWALD_SB, 17, LOOK.COIN_TEXT, 4)
		value.LayoutOrder = 2
		value.AutomaticSize = Enum.AutomaticSize.X
		value.Size = UDim2.fromOffset(0, 20)
		value.TextYAlignment = Enum.TextYAlignment.Center
		local caption = label(box, "Caption", SANS_SEMI, 9, LOOK.FAINT, 4)
		caption.LayoutOrder = 3
		caption.AutomaticSize = Enum.AutomaticSize.X
		caption.Size = UDim2.fromOffset(0, 12)
		caption.TextYAlignment = Enum.TextYAlignment.Center
		return box, value
	end

	local coinsPill, coinsText = pill("Coins", 1)
	local disc = coin(coinsPill, "Disc", 14, 4)
	disc.LayoutOrder = 1
	local coinsCaption = coinsPill:FindFirstChild("Caption") :: TextLabel
	coinsCaption.Text = spaced(TEXT.MONEY_CAP)
	coinsValue = coinsText

	local huntsPill, huntsText = pill("Hunts", 2)
	local mark = frame(huntsPill, "Mark", 4)
	mark.LayoutOrder = 1
	mark.Size = UDim2.fromOffset(13, 13)
	mark.BackgroundColor3 = LOOK.PINE
	corner(mark, 3)
	stroke(mark, LOOK.PINE_TEXT, 0.55)
	local huntsCaption = huntsPill:FindFirstChild("Caption") :: TextLabel
	huntsCaption.Text = spaced(TEXT.HUNTS_CAP)
	huntsText.TextColor3 = LOOK.PINE_TEXT
	huntsValue = huntsText

	-- THE CLOSE BUTTON: 44 x 44, and its X is TWO FRAMES. On a touch device it is the only way out
	-- of this panel other than walking away, because `Escape` belongs to the Roblox menu.
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AutoButtonColor = false
	close.Text = ""
	close.BackgroundColor3 = Color3.fromHex("221E18")
	close.BorderSizePixel = 0
	close.Size = UDim2.fromOffset(PANEL.CLOSE_PX, PANEL.CLOSE_PX)
	close.AnchorPoint = Vector2.new(1, 0)
	close.ZIndex = Z + 3
	close.Parent = root
	corner(close, 11)
	stroke(close, LOOK.LINE)
	for index, turn in ipairs({ 45, -45 }) do
		local bar_ = frame(close, string.format("Bar%d", index), 4)
		bar_.AnchorPoint = Vector2.new(0.5, 0.5)
		bar_.Position = UDim2.fromScale(0.5, 0.5)
		bar_.Size = UDim2.fromOffset(18, 2)
		bar_.BackgroundColor3 = LOOK.MUTED
		bar_.Rotation = turn
		corner(bar_, 1)
	end
	close.Activated:Connect(function()
		ShopPanel.setOpen(false)
	end)
	-- THE ONE PIECE OF MOTION IN THE PANEL: a 0.12 s colour tween on hover (spec 8.9).
	close.MouseEnter:Connect(function()
		TweenService:Create(close, TweenInfo.new(LOOK.HOVER_SECONDS), { BackgroundColor3 = LOOK.ROW_HOVER }):Play()
	end)
	close.MouseLeave:Connect(function()
		TweenService:Create(close, TweenInfo.new(LOOK.HOVER_SECONDS), { BackgroundColor3 = Color3.fromHex("221E18") })
			:Play()
	end)
end

-- ---------------------------------------------------------------- building: a tag chip

local function tagChip(parent: Instance, zOffset: number): Frame
	local chip = frame(parent, "Tag", zOffset)
	chip.Size = UDim2.fromOffset(0, PANEL.TAG_PX)
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.BackgroundColor3 = LOOK.PINE
	chip.BackgroundTransparency = 0.84
	corner(chip, 5)
	stroke(chip, LOOK.PINE, 0.45)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 7)
	pad.PaddingRight = UDim.new(0, 7)
	pad.Parent = chip
	local text = label(chip, "TagText", SANS_BOLD, 9, LOOK.PINE_TEXT, zOffset + 1)
	text.AutomaticSize = Enum.AutomaticSize.X
	text.Size = UDim2.fromOffset(0, PANEL.TAG_PX)
	text.TextYAlignment = Enum.TextYAlignment.Center
	return chip
end

-- THE COLOURS A TAG AND A ROW WEAR, per state (spec 5). One table, read by the row and the card, so
-- the two layouts cannot disagree about what OWNED looks like.
local TAG_COLOR: { [string]: Color3 } = {
	owned = LOOK.PINE_TEXT,
	locked = LOOK.AMBER,
	poor = LOOK.CLAY,
	soon = LOOK.FAINT,
	none = LOOK.FAINT,
}

local TAG_FILL: { [string]: Color3 } = {
	owned = LOOK.PINE,
	locked = LOOK.AMBER_BAR,
	poor = LOOK.CLAY,
	soon = LOOK.LINE,
	none = LOOK.LINE,
}

-- ---------------------------------------------------------------- building: the side menu

local function buildWell(root: Frame)
	local column = Instance.new("ScrollingFrame")
	column.Name = "Menu"
	column.BackgroundColor3 = LOOK.COLUMN
	column.BorderSizePixel = 0
	column.ScrollBarThickness = PANEL.SCROLLBAR_PX
	column.ScrollBarImageColor3 = LOOK.LINE
	column.ScrollingDirection = Enum.ScrollingDirection.Y
	column.CanvasSize = UDim2.new()
	column.AutomaticCanvasSize = Enum.AutomaticSize.Y
	column.ZIndex = Z + 1
	column.Parent = root
	corner(column, 13)
	stroke(column, LOOK.WELL_EDGE, 0.15)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, PANEL.WELL_PAD)
	pad.PaddingLeft = UDim.new(0, PANEL.WELL_PAD)
	pad.PaddingRight = UDim.new(0, PANEL.WELL_PAD)
	pad.PaddingBottom = UDim.new(0, PANEL.WELL_PAD)
	pad.Parent = column
	local stack = Instance.new("UIListLayout")
	stack.FillDirection = Enum.FillDirection.Vertical
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	-- TASK 228, AND IT IS THE SINGLE LINE THE SHOP2 SPEC CALLS *"most of the fix"* (section 1.2).
	-- Karen, 2026-10-21: *"cards on left side is cluttered a bit"*. At `Padding` 0 the eight rows
	-- SHARE THEIR EDGES and read as one striped slab; at 8 they read as eight things.
	stack.Padding = UDim.new(0, PANEL.ROW_GAP)
	stack.Parent = column
	well = column

	table.clear(menu)
	table.clear(shelves)
	local order = 0
	-- THE SHELVES AND THEIR ROWS ARE STATIC DATA -- `Shop.ORDER` and each row's `category` -- so the
	-- instances are made once and only their words, colours and tags are written per render. That is
	-- the discipline every panel in this Hud keeps.
	for index, group in ipairs(ShopData.groups(ShopData.rowsFor(nil, nil, nil, true))) do
		order += 1
		-- THE SHELF HEAD AND ITS TWO KINDS OF AIR (task 228, shop2 spec 1.4). `SHELF_LEAD` is the air
		-- ABOVE the head and is 0 for the first one in the list; `SHELF_TRAIL` is the air between the
		-- head's own band and its first row, given as this frame's `PaddingBottom` so the rows stay a
		-- plain `UIListLayout` sequence. One `SHELF_GAP` used to answer both and answered neither:
		-- the head sat 9 px under the row above it and 0 px over the row it names.
		-- THE STACK'S OWN `ROW_GAP` IS ALREADY BETWEEN THIS FRAME AND ITS NEIGHBOURS, so each side's
		-- padding carries only the REST of the air the spec asks to SEE. Without that subtraction
		-- the head would sit 28 px under the row above it and 18 over the row it names, and the
		-- canvas arithmetic the spec's fold is measured with (1.5: 1078 in a 480 viewport, five
		-- whole rows and one whole head above the fold) would be 72 px out.
		local lead = if index > 1 then PANEL.SHELF_LEAD - PANEL.ROW_GAP else 0
		local trail = PANEL.SHELF_TRAIL - PANEL.ROW_GAP
		local shelf = frame(column, string.format("Shelf_%s", group.category), 2)
		shelf.BackgroundTransparency = 1
		shelf.LayoutOrder = order
		shelf.Size = UDim2.new(1, 0, 0, lead + PANEL.SHELF_PX + trail)
		local band = Instance.new("UIPadding")
		band.PaddingTop = UDim.new(0, lead)
		band.PaddingBottom = UDim.new(0, trail)
		band.Parent = shelf
		local text = label(shelf, "ShelfText", SANS_BOLD, 10, LOOK.FAINT, 3)
		text.Text = spaced(group.label)
		text.AutomaticSize = Enum.AutomaticSize.X
		text.Size = UDim2.fromOffset(0, PANEL.SHELF_PX)
		text.TextYAlignment = Enum.TextYAlignment.Center
		-- A LABEL ON THE LEFT AND A RULE FILLING THE REST (spec 3.3). One hairline, never a box. It
		-- is centred in the head's OWN 20 px band, which the padding above has already made the
		-- frame's whole interior -- so there is no half-gap to add back by hand any more.
		local rule = frame(shelf, "ShelfRule", 3)
		rule.BackgroundColor3 = LOOK.LINE
		rule.BackgroundTransparency = 0.55
		rule.AnchorPoint = Vector2.new(1, 0.5)
		rule.Position = UDim2.fromScale(1, 0.5)
		rule.Size = UDim2.new(1, -(#group.label * 7 + 16), 0, 1)
		table.insert(shelves, text)

		for _, wireRow in ipairs(group.rows) do
			order += 1
			local id = wireRow.id
			local made = Instance.new("TextButton")
			made.Name = string.format("Item_%s", id)
			made.AutoButtonColor = false
			made.Text = ""
			made.BackgroundColor3 = LOOK.ROW
			made.BorderSizePixel = 0
			made.LayoutOrder = order
			made.Size = UDim2.new(1, 0, 0, PANEL.ROW_PX)
			made.ClipsDescendants = true
			made.ZIndex = Z + 2
			made.Parent = column
			corner(made, 11)
			local edge = stroke(made, LOOK.BLAZE, 1)
			edge.Name = "Edge"
			-- THE SELECTED ROW'S 4 PX BAR, built here and shown by `render`: *"no other row carries
			-- an orange anything, so the selected row is the only orange thing in the list"*.
			local bar = frame(made, "Bar", 3)
			bar.Size = UDim2.new(0, 4, 1, 0)
			bar.Visible = false
			verticalGradient(
				bar,
				ColorSequence.new({
					ColorSequenceKeypoint.new(0, LOOK.BLAZE_HI),
					ColorSequenceKeypoint.new(1, LOOK.BLAZE_LO),
				})
			)
			-- ONE ROW, INSIDE (task 228, shop2 spec 1.3). Left inset 14, right inset 12, and the
			-- interior air is 11 top / 6 between the two lines / 11 bottom -- it was 10 / 2 / 12,
			-- and *"the 6 is what makes a row look like two facts instead of one lump"*.
			--
			-- THE NAME LINE STAYS CLEAR: no tag, no chip, no second number on it, ever. That rule is
			-- what buys the row its calm. The truncate is insurance and not a plan -- the longest
			-- name in the catalogue, `SEMI-AUTO SHOTGUN`, measures 118 px of the 190 it has.
			local name = label(made, "Name", OSWALD_MD, 16, LOOK.PAPER, 3)
			name.Position = UDim2.fromOffset(14, 11)
			name.Size = UDim2.new(1, -26, 0, 19)
			name.TextTruncate = Enum.TextTruncate.AtEnd
			local disc = coin(made, "PriceCoin", 11, 3)
			disc.Position = UDim2.fromOffset(14, 39)
			local price = label(made, "Price", OSWALD_MD, 14, LOOK.COIN_TEXT, 3)
			price.Position = UDim2.fromOffset(31, 36)
			price.Size = UDim2.fromOffset(90, 17)
			-- THE TAG'S 19 PX BAND (35..54) IS CENTRED ON THE PRICE'S 17 PX BAND (36..53). Both used
			-- to be written at y 31 and sat 1 px out.
			local chip = tagChip(made, 3)
			chip.AnchorPoint = Vector2.new(1, 0)
			chip.Position = UDim2.new(1, -12, 0, 35)
			-- THE ROLE SWITCH LIVES IN ONE ROW AND IN NO OTHER (task 229, spec 3.4). The row is
			-- built at `ROW_SWITCH_PX` 124 instead of 64 by `relayout`, and one row taller than the
			-- rest is the point: *"it marks the thing you own as a thing you OPERATE"*.
			--
			-- HIDDEN UNTIL THE SERVER SAYS HE OWNS IT. A man who owns nothing never sees it --
			-- absent, not greyed and not locked.
			if id == ShopData.ITEM.ALWAYS_HUNTER then
				local block = frame(made, "RoleBlock", 3)
				block.BackgroundTransparency = 1
				block.Visible = false
				rowBlock = block
				local brow = label(block, "RoleEyebrow", SANS_BOLD, 10, LOOK.FAINT, 4)
				brow.Name = "RoleEyebrow"
				brow.Text = spaced(TEXT.ROLE_TITLE)
				brow.Size = UDim2.new(1, 0, 0, 12)
				local note = label(block, "RoleCaption", SANS_BOLD, 10, LOOK.FAINT, 4)
				note.Name = "RoleCaption"
				note.Size = UDim2.new(1, 0, 0, 12)
				note.TextTruncate = Enum.TextTruncate.AtEnd
				-- THE HALVES SIT AT `Z + 4` OVER THE ROW'S `Z + 2` and its children's `Z + 3`, so
				-- Roblox routes a press to a half rather than to the row under it -- and the row IS
				-- a `TextButton`, so that is the whole of the hit test. The band is one this panel
				-- already occupies (the header's wallet and the buy button are at `Z + 4`, the two
				-- well fade masks at `Z + 6`).
				--
				-- A PRESS ALSO SELECTS THE ROW, and the order is select-then-ask: *"a clumsy tap
				-- never does nothing, and the case swings round to the pin you just set"*. `select`
				-- is a no-op when the row is already selected, so a second press costs one message
				-- and no redraw.
				rowSwitch = ShopPanel.buildRoleSwitch(
					block,
					4,
					PANEL.SWITCH_WORD_PX,
					{ [ShopPanel.ROLE.HUNTER] = TEXT.ROLE_HUNTER, [ShopPanel.ROLE.BEATER] = TEXT.ROLE_BEATER },
					function(which: string)
						ShopPanel.select(id)
						ShopPanel.askRole(which)
					end
				)
			end
			-- THE ID IS CLOSED OVER AND NOTHING ELSE IS. A click SELECTS; it never buys and never
			-- reads a price, so a row drawing a different item after a redraw cannot buy the one it
			-- used to show.
			made.Activated:Connect(function()
				ShopPanel.select(id)
			end)
			made.MouseEnter:Connect(function()
				if selected ~= id then
					TweenService:Create(made, TweenInfo.new(LOOK.HOVER_SECONDS), { BackgroundColor3 = LOOK.ROW_HOVER })
						:Play()
				end
			end)
			made.MouseLeave:Connect(function()
				if selected ~= id then
					ShopPanel.render()
				end
			end)
			table.insert(menu, { id = id, row = made })
		end
	end

	-- THE TWO FADE MASKS (task 228, shop2 spec 1.5), so a row scrolling under the well's top edge
	-- DISSOLVES instead of being guillotined. They are children of the well's PARENT and not of the
	-- `ScrollingFrame`, or they would scroll with the rows they are masking; they are placed by
	-- `relayout`, which is the one writer of every rectangle in this panel; and they are never
	-- pressable (`Active = false`), so a press over the top row still reaches the row.
	for _, side in ipairs({ { name = "FadeTop", rotation = 0 }, { name = "FadeBottom", rotation = 180 } }) do
		local mask = frame(root, side.name, 6)
		mask.Name = side.name
		mask.BackgroundColor3 = LOOK.COLUMN
		mask.Active = false
		mask.Visible = false
		local paint = Instance.new("UIGradient")
		paint.Rotation = 90 + side.rotation
		paint.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		paint.Parent = mask
		if side.name == "FadeTop" then
			wellFadeTop = mask
		else
			wellFadeBottom = mask
		end
	end
end

-- ---------------------------------------------------------------- building: the phone's strip

local function buildStrip(root: Frame)
	local rail = Instance.new("ScrollingFrame")
	rail.Name = "Strip"
	rail.BackgroundTransparency = 1
	rail.BorderSizePixel = 0
	rail.ScrollBarThickness = 0
	rail.ScrollingDirection = Enum.ScrollingDirection.X
	rail.CanvasSize = UDim2.new()
	rail.AutomaticCanvasSize = Enum.AutomaticSize.X
	rail.ZIndex = Z + 1
	rail.Parent = root
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, PANEL.STRIP_PAD)
	-- ...AND THE LAST CARD CAN SCROLL CLEAR OF IT: the right padding carries the fade's width as
	-- well, so a card scrolled to the end stops beside the hint instead of under it.
	pad.PaddingRight = UDim.new(0, PANEL.STRIP_PAD + PANEL.STRIP_FADE)
	pad.Parent = rail
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.SortOrder = Enum.SortOrder.LayoutOrder
	-- EVERY GAP IN THIS STRIP IS A SPACER FRAME AND NOT THE LAYOUT'S PADDING (task 228, shop2 spec
	-- 1.6), because the two gaps are different widths: 10 between two cards in a category and 18
	-- across a category boundary. A layout padding applies on BOTH sides of a spacer, so a padding
	-- of 10 could never produce a boundary of 18 -- the spacer would have to be -2 wide. With the
	-- padding at 0, each gap is exactly the frame that is in it, and the boundary's frame is the one
	-- that carries the hairline.
	row.Padding = UDim.new(0, 0)
	row.Parent = rail
	strip = rail

	-- ONE GAP BETWEEN TWO CARDS. `rule` is true at a category boundary, where the gap is wider and
	-- has a 1 px hairline down its middle -- *"the strip has no room for a word; a rule is the
	-- honest version of a shelf head"*. The player still learns the category from the eyebrow over
	-- the item's name in the detail pane, which already says WEAPONS / AMMO / LICENCES / ACCESS /
	-- PACKAGES.
	local function spacer(name: string, order: number, width: number, rule: boolean)
		local gap = frame(rail, name, 2)
		gap.BackgroundTransparency = 1
		gap.LayoutOrder = order
		gap.Size = UDim2.fromOffset(width, PANEL.STRIP_PX)
		if rule then
			local hair = frame(gap, "GroupRule", 3)
			hair.BackgroundColor3 = LOOK.LINE
			hair.BackgroundTransparency = 0.55
			hair.AnchorPoint = Vector2.new(0.5, 0)
			hair.Position = UDim2.fromScale(0.5, 0)
			hair.Size = UDim2.new(0, 1, 1, 0)
		end
	end

	table.clear(cards)
	local order = 0
	for groupIndex, group in ipairs(ShopData.groups(ShopData.rowsFor(nil, nil, nil, true))) do
		if groupIndex > 1 then
			order += 1
			spacer(string.format("GroupGap_%s", group.category), order, PANEL.CARD_GROUP_GAP, true)
		end
		for cardIndex, wireRow in ipairs(group.rows) do
			if cardIndex > 1 then
				order += 1
				spacer(string.format("CardGap_%s_%d", group.category, cardIndex), order, PANEL.CARD_GAP, false)
			end
			order += 1
			local id = wireRow.id
			local card = Instance.new("TextButton")
			card.Name = string.format("Card_%s", id)
			card.AutoButtonColor = false
			card.Text = ""
			card.BackgroundColor3 = LOOK.ROW
			card.BorderSizePixel = 0
			card.LayoutOrder = order
			card.Size = UDim2.fromOffset(PANEL.CARD_WIDTH, PANEL.STRIP_PX)
			card.ClipsDescendants = true
			card.ZIndex = Z + 2
			card.Parent = rail
			corner(card, 11)
			local edge = stroke(card, LOOK.WELL_EDGE, 0)
			edge.Name = "Edge"
			local cardPad = Instance.new("UIPadding")
			cardPad.PaddingLeft = UDim.new(0, 10)
			cardPad.PaddingTop = UDim.new(0, 9)
			cardPad.PaddingRight = UDim.new(0, 9)
			cardPad.Parent = card
			-- INSIDE A CARD (task 228, shop2 spec 1.6): the tag top-right, the name at the BOTTOM and
			-- the price under it, with the top of the card left as the picture slot. THE CATEGORY
			-- WORD IS GONE from the card -- the rule between two groups says it now, and the
			-- eyebrow over the name in the detail pane says it in words.
			--
			-- NOTHING DRAWS IN THE PICTURE SLOT YET, and that is deliberate: a `ViewportFrame` per
			-- card would be ten cameras in a strip, which is exactly the count `Hud.ReportPanel`
			-- refused one for. The slot is the air the tag sits in.
			local name = label(card, "Name", SANS_SEMI, 11, LOOK.PAPER, 3)
			name.AnchorPoint = Vector2.new(0, 1)
			name.Position = UDim2.new(0, 0, 1, -26)
			name.Size = UDim2.new(1, 0, 0, 26)
			name.TextWrapped = true
			name.TextTruncate = Enum.TextTruncate.AtEnd
			name.TextYAlignment = Enum.TextYAlignment.Bottom
			local disc = coin(card, "PriceCoin", 10, 3)
			disc.AnchorPoint = Vector2.new(0, 1)
			disc.Position = UDim2.new(0, 0, 1, -11)
			local price = label(card, "Price", OSWALD_MD, 12, LOOK.COIN_TEXT, 3)
			price.AnchorPoint = Vector2.new(0, 1)
			price.Position = UDim2.new(0, 15, 1, -6)
			price.Size = UDim2.new(1, -15, 0, 16)
			local chip = tagChip(card, 3)
			chip.AnchorPoint = Vector2.new(1, 0)
			chip.Position = UDim2.fromScale(1, 0)
			card.Activated:Connect(function()
				ShopPanel.select(id)
			end)
			table.insert(cards, { id = id, card = card })
		end
	end

	-- THE FADE ON THE RIGHT EDGE, which is how the player learns the strip scrolls (spec 3.4).
	local fade = frame(root, "StripFade", 3)
	fade.BackgroundColor3 = LOOK.PANEL
	fade.AnchorPoint = Vector2.new(1, 0)
	local paint = Instance.new("UIGradient")
	paint.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	paint.Parent = fade
	stripFade = fade
end

-- ---------------------------------------------------------------- building: the display case
--
-- THE CASE IS UI, NOT VIEWPORT (spec 3.5): a dark gradient box with a warm top light, a contact
-- shadow on the shelf and a brass shelf line, with a TRANSPARENT `ViewportFrame` over it. A
-- `ViewportFrame` cannot draw any of those four things, and the model inside it does not have to.
local function buildCase(parent: Frame)
	local box = frame(parent, "Case", 1)
	box.BackgroundColor3 = LOOK.CASE_MID
	corner(box, 13)
	stroke(box, LOOK.BRASS, 0.8)
	box.ClipsDescendants = true
	verticalGradient(
		box,
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, LOOK.CASE_TOP),
			ColorSequenceKeypoint.new(0.58, LOOK.CASE_MID),
			ColorSequenceKeypoint.new(1, LOOK.CASE_FLOOR),
		})
	)
	caseFrame = box

	local top = frame(box, "TopLight", 2)
	top.BackgroundColor3 = LOOK.HIGHLIGHT
	top.Size = UDim2.new(1, 0, 0, 96)
	local light = Instance.new("UIGradient")
	light.Rotation = 90
	light.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.84),
		NumberSequenceKeypoint.new(1, 1),
	})
	light.Parent = top

	local shadow = frame(box, "ShelfShadow", 2)
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.AnchorPoint = Vector2.new(0.5, 1)
	shadow.Size = UDim2.fromOffset(230, 34)
	corner(shadow, 17)
	local soft = Instance.new("UIGradient")
	soft.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.38),
		NumberSequenceKeypoint.new(1, 1),
	})
	soft.Parent = shadow

	local shelfLine = frame(box, "ShelfLine", 2)
	shelfLine.BackgroundColor3 = LOOK.BRASS
	shelfLine.AnchorPoint = Vector2.new(0.5, 1)
	local glow = Instance.new("UIGradient")
	glow.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.22, 0.8),
		NumberSequenceKeypoint.new(0.78, 0.8),
		NumberSequenceKeypoint.new(1, 1),
	})
	glow.Parent = shelfLine

	local glass = Instance.new("ViewportFrame")
	glass.Name = "Picture"
	glass.BackgroundTransparency = 1
	glass.BorderSizePixel = 0
	glass.Size = UDim2.fromScale(1, 1)
	glass.ZIndex = Z + 3
	-- THE VIEWPORT'S OWN LIGHT, because it has no Lighting service of its own: a model in a
	-- `ViewportFrame` is lit by these three properties and by nothing else.
	glass.LightDirection = ShopDisplay.LIGHT_DIRECTION
	glass.LightColor = ShopDisplay.LIGHT_COLOR
	glass.Ambient = ShopDisplay.AMBIENT
	glass.Parent = box
	viewport = glass

	local camera = Instance.new("Camera")
	camera.Name = "PictureCamera"
	camera.FieldOfView = ShopDisplay.FOV_DEG
	camera.Parent = glass
	-- A `ViewportFrame` RENDERS THROUGH ITS OWN `CurrentCamera` AND NOT THE WORKSPACE'S. Forgetting
	-- this line is the way a viewport comes out as a flat colour with the model inside it.
	glass.CurrentCamera = camera
	viewportCamera = camera
end

-- ---------------------------------------------------------------- building: the one big button

local function buildButton(parent: Frame)
	local made = Instance.new("TextButton")
	made.Name = "Buy"
	made.AutoButtonColor = false
	made.Text = ""
	made.BackgroundColor3 = LOOK.BLAZE
	made.BorderSizePixel = 0
	made.ClipsDescendants = true
	made.ZIndex = Z + 2
	made.Parent = parent
	corner(made, 12)
	buyStroke = stroke(made, LOOK.BLAZE_EDGE)
	buyGradient = verticalGradient(
		made,
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, LOOK.BUY_TOP),
			ColorSequenceKeypoint.new(0.52, LOOK.BUY_MID),
			ColorSequenceKeypoint.new(1, LOOK.BLAZE_LO),
		})
	)

	-- A TOP HIGHLIGHT ON THE LIVE BUY STATES: one inside edge, inset 12 px each side.
	local highlight = frame(made, "Highlight", 3)
	highlight.BackgroundColor3 = LOOK.HIGHLIGHT
	highlight.BackgroundTransparency = 0.62
	highlight.Position = UDim2.fromOffset(12, 1)
	highlight.Size = UDim2.new(1, -24, 0, 1)
	buyHighlight = highlight

	-- THE LOCKED BUTTON CARRIES THE PROGRESS, along its bottom inside edge.
	local track = frame(made, "Progress", 3)
	track.BackgroundColor3 = LOOK.AMBER_BAR
	track.BackgroundTransparency = 0.82
	track.AnchorPoint = Vector2.new(0, 1)
	track.Position = UDim2.fromScale(0, 1)
	track.Size = UDim2.new(1, 0, 0, 4)
	track.Visible = false
	buyProgress = track
	local fill = frame(track, "Fill", 4)
	fill.BackgroundColor3 = LOOK.AMBER
	fill.Size = UDim2.fromScale(0, 1)
	local sweep = Instance.new("UIGradient")
	sweep.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, LOOK.AMBER_BAR),
		ColorSequenceKeypoint.new(1, LOOK.AMBER),
	})
	sweep.Parent = fill
	buyProgressFill = fill

	-- THE CONTENTS: a centred horizontal row -- the word, a hairline divider, a coin, the amount.
	local row = frame(made, "Contents", 3)
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, 0.5)
	row.Size = UDim2.new(1, -24, 1, 0)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 11)
	list.Parent = row

	-- THE TICK on the OWNED button is two Frames, rotated: no glyph has to exist in the font.
	local tick = frame(row, "Tick", 4)
	tick.BackgroundTransparency = 1
	tick.LayoutOrder = 1
	tick.Size = UDim2.fromOffset(16, 14)
	tick.Visible = false
	local short = frame(tick, "TickShort", 5)
	short.BackgroundColor3 = LOOK.PINE_TEXT
	short.AnchorPoint = Vector2.new(0.5, 0.5)
	short.Position = UDim2.fromScale(0.26, 0.66)
	short.Size = UDim2.fromOffset(7, 2.5)
	short.Rotation = 45
	corner(short, 1)
	local long = frame(tick, "TickLong", 5)
	long.BackgroundColor3 = LOOK.PINE_TEXT
	long.AnchorPoint = Vector2.new(0.5, 0.5)
	long.Position = UDim2.fromScale(0.62, 0.45)
	long.Size = UDim2.fromOffset(12, 2.5)
	long.Rotation = -50
	corner(long, 1)
	buyTick = tick

	local word = label(row, "Word", SANS_BOLD, 17, LOOK.BUTTON_TEXT, 4)
	word.LayoutOrder = 2
	word.AutomaticSize = Enum.AutomaticSize.X
	word.Size = UDim2.fromOffset(0, 22)
	word.TextYAlignment = Enum.TextYAlignment.Center
	buyWord = word

	local divider = frame(row, "Divider", 4)
	divider.LayoutOrder = 3
	divider.BackgroundColor3 = Color3.fromHex("FFECD0")
	divider.BackgroundTransparency = 0.7
	divider.Size = UDim2.fromOffset(1, 20)
	buyDivider = divider

	local disc = coin(row, "Coin", 15, 4)
	disc.LayoutOrder = 4
	buyCoin = disc

	local amount = label(row, "Amount", OSWALD_SB, 19, LOOK.BUTTON_TEXT, 4)
	amount.LayoutOrder = 5
	amount.AutomaticSize = Enum.AutomaticSize.X
	amount.Size = UDim2.fromOffset(0, 24)
	amount.TextYAlignment = Enum.TextYAlignment.Center
	buyAmount = amount

	made.Activated:Connect(function()
		ShopPanel.pressSelected()
	end)
	made.MouseEnter:Connect(function()
		local row_ = ShopPanel.rowFor(selected)
		if row_ ~= nil and row_.buyable == true then
			TweenService:Create(made, TweenInfo.new(LOOK.HOVER_SECONDS), { BackgroundColor3 = LOOK.BLAZE_HI }):Play()
		end
	end)
	made.MouseLeave:Connect(function()
		ShopPanel.render()
	end)
	buyButton = made
end

-- ---------------------------------------------------------------- building: the detail column

local function buildDetail(root: Frame)
	local column = frame(root, "Detail", 1)
	column.BackgroundTransparency = 1
	detail = column

	buildCase(column)

	eyebrowLabel = label(column, "Eyebrow", SANS_BOLD, 10, LOOK.BLAZE_HI, 2)
	nameLabel = label(column, "ItemName", OSWALD_SB, 27, LOOK.PAPER, 2)

	-- THE PRICE LINE IS A ROW AND NOT THREE PLACED LABELS, and the first frame is why (rule 5,
	-- `.screenshots/196-shop-desktop.png`): the number is `AutomaticSize`, so a caption placed at a
	-- fixed x was overrun by it and came out as a single stray letter beside the figure. A
	-- `UIListLayout` puts the coin, the number and the unit in a line whatever the number is.
	local priceRow = frame(column, "PriceRow", 2)
	priceRow.BackgroundTransparency = 1
	local priceList = Instance.new("UIListLayout")
	priceList.FillDirection = Enum.FillDirection.Horizontal
	priceList.VerticalAlignment = Enum.VerticalAlignment.Center
	priceList.SortOrder = Enum.SortOrder.LayoutOrder
	priceList.Padding = UDim.new(0, 8)
	priceList.Parent = priceRow
	priceCoin = coin(priceRow, "Coin", 17, 3);
	(priceCoin :: Frame).LayoutOrder = 1
	priceLabel = label(priceRow, "Price", OSWALD_SB, 24, LOOK.COIN_TEXT, 3);
	(priceLabel :: TextLabel).LayoutOrder = 2
	(priceLabel :: TextLabel).AutomaticSize = Enum.AutomaticSize.X;
	(priceLabel :: TextLabel).Size = UDim2.fromOffset(0, 26);
	(priceLabel :: TextLabel).TextYAlignment = Enum.TextYAlignment.Center
	priceCaption = label(priceRow, "Caption", SANS_SEMI, 10, LOOK.FAINT, 3);
	-- `PRICE_CAP` AND NOT THE WALLET'S CAPTION (task 221). This line and the wallet pill both read
	-- `COINS_CAP` before, and they answer different questions -- *what this costs* and *how much he
	-- has*. A caption reading MONEY over a price is the drift the split prevents.
	(priceCaption :: TextLabel).Text = spaced(TEXT.PRICE_CAP);
	(priceCaption :: TextLabel).LayoutOrder = 3
	(priceCaption :: TextLabel).AutomaticSize = Enum.AutomaticSize.X;
	(priceCaption :: TextLabel).Size = UDim2.fromOffset(0, 14);
	(priceCaption :: TextLabel).TextYAlignment = Enum.TextYAlignment.Center

	ruleLine = frame(column, "Rule", 2);
	(ruleLine :: Frame).BackgroundColor3 = LOOK.LINE

	blurbLabel = label(column, "Blurb", SANS_REG, 14, LOOK.BODY, 2);
	(blurbLabel :: TextLabel).TextWrapped = true
	(blurbLabel :: TextLabel).LineHeight = 1.5

	local status = frame(column, "Status", 2)
	status.BackgroundTransparency = 1
	statusDot = frame(status, "Dot", 3);
	(statusDot :: Frame).BackgroundColor3 = LOOK.FAINT;
	(statusDot :: Frame).Size = UDim2.fromOffset(4, 4);
	(statusDot :: Frame).Position = UDim2.fromOffset(0, 5)
	corner(statusDot :: Frame, 2)
	statusLabel = label(status, "StatusText", SANS_SEMI, 11, LOOK.FAINT, 3);
	(statusLabel :: TextLabel).Position = UDim2.fromOffset(12, 0);
	(statusLabel :: TextLabel).Size = UDim2.new(1, -12, 0, 14)

	-- THE PHONE'S SURFACE (task 229, spec 3.5). The 108 px card has no room for a switch, so on a
	-- phone it rides the detail pane: the 14 px status row becomes a 70 px block
	-- (`eyebrow 12 / 6 / track 34 / 6 / caption 12`) directly above the `OWNED` button, and the
	-- blurb box absorbs the difference exactly as `layoutFor` already absorbs everything else.
	--
	-- **ONE RULE, BOTH MODES: the switch appears once, on whichever surface the item has**, and
	-- `ShopPanel.switchSurfaceFor` is that rule as a function rather than as a convention.
	local pane = frame(column, "RoleBlock", 2)
	pane.BackgroundTransparency = 1
	pane.Visible = false
	detailBlock = pane
	local paneBrow = label(pane, "RoleEyebrow", SANS_BOLD, 10, LOOK.FAINT, 3)
	paneBrow.Text = spaced(TEXT.ROLE_TITLE)
	paneBrow.Size = UDim2.new(1, 0, 0, 12)
	local paneNote = label(pane, "RoleCaption", SANS_BOLD, 10, LOOK.FAINT, 3)
	paneNote.Size = UDim2.new(1, 0, 0, 12)
	paneNote.TextTruncate = Enum.TextTruncate.AtEnd
	detailSwitch = ShopPanel.buildRoleSwitch(
		pane,
		3,
		PANEL.SWITCH_WORD_TALL_PX,
		{ [ShopPanel.ROLE.HUNTER] = TEXT.ROLE_HUNTER, [ShopPanel.ROLE.BEATER] = TEXT.ROLE_BEATER },
		function(which: string)
			ShopPanel.askRole(which)
		end
	)

	buildButton(column)
end

local function build(root: Frame)
	panel = root
	root.BackgroundColor3 = LOOK.PANEL
	root.BackgroundTransparency = 0
	root.BorderSizePixel = 0
	root.ClipsDescendants = false
	corner(root, PANEL.CORNER)
	stroke(root, LOOK.BRASS, 0.74)

	-- THE SCRIM IS THE ONE THING THIS MODULE DRAWS OUTSIDE ITS OWN FRAME, and it is a SIBLING rather
	-- than a child because it has to sit BEHIND the panel (a child must be above it, which is task
	-- 124's rule). It is still this module's alone -- nothing else writes it, and it is shown and
	-- hidden with the panel in `setOpen`.
	local shade = Instance.new("Frame")
	shade.Name = "ShopScrim"
	shade.BackgroundColor3 = LOOK.SCRIM
	shade.BackgroundTransparency = PANEL.SCRIM_TRANSPARENCY
	shade.BorderSizePixel = 0
	shade.Size = UDim2.fromScale(1, 1)
	shade.Position = UDim2.new()
	shade.ZIndex = Z - 1
	shade.Visible = false
	shade.Parent = root.Parent
	scrim = shade

	buildHeader(root)
	buildWell(root)
	buildStrip(root)
	buildDetail(root)

	ShopPanel.relayout()
end

-- ---------------------------------------------------------------- the rectangles, written
--
-- ONE WRITER OF EVERY POSITION AND SIZE IN THIS PANEL, from the ONE pure layout. Called at build and
-- whenever the screen changes size, so a phone turned on its side is the same panel re-measured
-- rather than a second layout path.
function ShopPanel.relayout()
	local root = panel
	if root == nil then
		return
	end
	stats.layouts += 1
	local size = screenSize()
	screenWas = size
	-- WHICH SURFACE THE ROLE SWITCH IS ON (task 229), decided ONCE here by the one pure rule and
	-- never twice: `switchSurfaceFor` is what makes *"never both"* an assertion.
	local wideNow = math.clamp(size.X - 2 * PANEL.MARGIN, PANEL.MIN_WIDTH, PANEL.MAX_WIDTH) >= PANEL.WIDE_AT
	local surface = ShopPanel.switchSurfaceFor(if wideNow then "WIDE" else "TALL", roleWish, selected)
	local layout = ShopPanel.layoutFor(size.X, size.Y, surface)
	local wide = layout.mode == "WIDE"
	root.Size = UDim2.fromOffset(layout.width, layout.height)

	local header = root:FindFirstChild("Header") :: Frame?
	if header then
		header.Size = UDim2.new(1, 0, 0, layout.headerHeight)
	end
	local hair = root:FindFirstChild("HeaderRule") :: Frame?
	if hair then
		hair.Position = UDim2.fromOffset(0, layout.headerHeight - 1)
		hair.Size = UDim2.new(1, 0, 0, 1)
	end
	local pad = if wide then 20 else 16
	local eyebrow = root:FindFirstChild("Eyebrow") :: TextLabel?
	if eyebrow then
		eyebrow.Position = UDim2.fromOffset(pad, 11)
		eyebrow.Size = UDim2.new(0.5, 0, 0, 11)
	end
	if title then
		(title :: TextLabel).Position = UDim2.fromOffset(pad, 24);
		(title :: TextLabel).Size = UDim2.new(0.5, 0, 0, 25);
		(title :: TextLabel).TextSize = if wide then 23 else 22
	end
	local wallet = root:FindFirstChild("Wallet") :: Frame?
	if wallet then
		wallet.Position = UDim2.new(1, -(if wide then 76 else 64), 0, if wide then 14 else 16)
		wallet.Size = UDim2.fromOffset(280, if wide then 36 else 32)
		for _, name in ipairs({ "Coins", "Hunts" }) do
			local pill = wallet:FindFirstChild(name) :: Frame?
			if pill then
				pill.Size = UDim2.fromOffset(0, if wide then 36 else 32)
			end
		end
	end
	local close = root:FindFirstChild("Close") :: TextButton?
	if close then
		close.Position = UDim2.new(1, -(if wide then 16 else 12), 0, 10)
	end

	if well then
		(well :: ScrollingFrame).Visible = wide;
		(well :: ScrollingFrame).Position = UDim2.fromOffset(layout.wellX, layout.wellY);
		(well :: ScrollingFrame).Size = UDim2.fromOffset(layout.wellWidth, layout.wellHeight)
	end
	-- THE FADES SIT INSIDE THE WELL'S OWN PADDING, over its top and bottom inside edge: 12 px in from
	-- each side so they stop at the rows' own width, and `WELL_FADE` tall.
	local fadeInset = PANEL.WELL_PAD
	if wellFadeTop then
		(wellFadeTop :: Frame).Visible = wide;
		(wellFadeTop :: Frame).Position = UDim2.fromOffset(layout.wellX + fadeInset, layout.wellY + 1);
		(wellFadeTop :: Frame).Size = UDim2.fromOffset(layout.rowWidth, PANEL.WELL_FADE)
	end
	if wellFadeBottom then
		(wellFadeBottom :: Frame).Visible = wide;
		(wellFadeBottom :: Frame).Position =
			UDim2.fromOffset(layout.wellX + fadeInset, layout.wellY + layout.wellHeight - PANEL.WELL_FADE - 1);
		(wellFadeBottom :: Frame).Size = UDim2.fromOffset(layout.rowWidth, PANEL.WELL_FADE)
	end
	if strip then
		(strip :: ScrollingFrame).Visible = not wide;
		(strip :: ScrollingFrame).Position = UDim2.fromOffset(0, layout.stripY);
		(strip :: ScrollingFrame).Size = UDim2.fromOffset(layout.width, layout.stripHeight)
	end
	if stripFade then
		-- THE FADE IS ANCHORED AT ITS OWN RIGHT EDGE (`AnchorPoint` 1, 0), so `UDim2.new(1, 0, ...)`
		-- already lands it flush inside the panel -- measured at 417..443 in a 12..443 panel. An
		-- earlier part-3f edit pulled it back by its own width on the assumption that it was
		-- anchored at its left, and moved it 44 px INTO the strip; this line is the original.
		-- What was actually wrong was its WIDTH: see `STRIP_FADE`.
		(stripFade :: Frame).Visible = not wide;
		(stripFade :: Frame).Position = UDim2.new(1, 0, 0, layout.stripY);
		(stripFade :: Frame).Size = UDim2.fromOffset(PANEL.STRIP_FADE, layout.stripHeight)
	end

	if detail then
		(detail :: Frame).Position = UDim2.fromOffset(layout.detailX, layout.detailY);
		(detail :: Frame).Size = UDim2.fromOffset(layout.detailWidth, layout.detailHeight)
	end
	-- EVERYTHING BELOW IS IN THE DETAIL COLUMN'S OWN FRAME, so each y is the layout's less the
	-- column's own top.
	local top = layout.detailY
	if caseFrame then
		(caseFrame :: Frame).Position = UDim2.fromOffset(0, layout.caseY - top);
		(caseFrame :: Frame).Size = UDim2.fromOffset(layout.caseWidth, layout.caseHeight)
		local shadow = (caseFrame :: Frame):FindFirstChild("ShelfShadow") :: Frame?
		if shadow then
			shadow.Position = UDim2.new(0.5, 0, 1, -46)
			shadow.Size = UDim2.fromOffset(math.floor(layout.caseWidth * 0.63), 34)
		end
		local line = (caseFrame :: Frame):FindFirstChild("ShelfLine") :: Frame?
		if line then
			line.Position = UDim2.new(0.5, 0, 1, -30)
			line.Size = UDim2.new(1, -60, 0, 1)
		end
	end
	local function put(instance: GuiObject?, y: number, height: number)
		if instance ~= nil then
			instance.Position = UDim2.fromOffset(0, y - top)
			instance.Size = UDim2.new(1, 0, 0, height)
		end
	end
	put(eyebrowLabel, layout.eyebrowY, PANEL.EYEBROW_PX)
	put(nameLabel, layout.nameY, PANEL.NAME_PX)
	if nameLabel then
		(nameLabel :: TextLabel).TextSize = if wide then 27 else 26
	end
	local priceRow = if detail then (detail :: Frame):FindFirstChild("PriceRow") :: Frame? else nil
	put(priceRow, layout.priceY, PANEL.PRICE_PX)
	put(ruleLine, layout.ruleY, 1)
	put(blurbLabel, layout.blurbY, layout.blurbHeight)
	local status = if detail then (detail :: Frame):FindFirstChild("Status") :: Frame? else nil
	put(status, layout.statusY, PANEL.STATUS_PX)
	put(buyButton, layout.buttonY, layout.buttonHeight)

	-- ---------------- THE ROLE SWITCH'S TWO SURFACES (task 229)
	--
	-- THE OWNED `ALWAYS HUNTER` ROW, IN WIDE. It is built at `ROW_SWITCH_PX` 124 instead of 64, and
	-- **nothing above it moves**: the well is a `UIListLayout`, so one row growing pushes only what
	-- is BELOW it, which is what `shop_panel.spec` asserts against `layoutFor(1280, 720)`.
	--
	-- THE PRICE LINE GOES, AND THE `OWNED` CHIP MOVES UP TO THE NAME LINE ON THIS ROW ONLY: *"the
	-- price of a thing you own is not news"* is this panel's own existing rule for an owned card,
	-- applied here because this row has no price line left for the chip to sit on.
	for _, entry in ipairs(menu) do
		if entry.id ~= ShopData.ITEM.ALWAYS_HUNTER then
			continue
		end
		local tall = surface == "row"
		entry.row.Size = UDim2.new(1, 0, 0, if tall then PANEL.ROW_SWITCH_PX else PANEL.ROW_PX)
		local disc = entry.row:FindFirstChild("PriceCoin") :: Frame?
		local price = entry.row:FindFirstChild("Price") :: TextLabel?
		if disc then
			disc.Visible = not tall
		end
		if price then
			price.Visible = not tall
		end
		local chip = entry.row:FindFirstChild("Tag") :: Frame?
		if chip then
			chip.Position = UDim2.new(1, -PANEL.SWITCH_RIGHT, 0, if tall then PANEL.SWITCH_NAME_Y else 35)
		end
		if rowBlock then
			local block = rowBlock :: Frame
			block.Visible = tall
			block.Position = UDim2.fromOffset(PANEL.SWITCH_LEFT, PANEL.SWITCH_EYEBROW_Y)
			block.Size = UDim2.fromOffset(layout.switchTrackWidth, PANEL.SWITCH_CAPTION_Y + 12 - PANEL.SWITCH_EYEBROW_Y)
		end
		if rowSwitch then
			rowSwitch.track.Position = UDim2.fromOffset(0, PANEL.SWITCH_TRACK_Y - PANEL.SWITCH_EYEBROW_Y)
			rowSwitch.track.Size = UDim2.fromOffset(layout.switchTrackWidth, PANEL.SWITCH_TRACK_PX)
		end
		if rowBlock then
			local note = (rowBlock :: Frame):FindFirstChild("RoleCaption") :: TextLabel?
			if note then
				note.Position = UDim2.fromOffset(0, PANEL.SWITCH_CAPTION_Y - PANEL.SWITCH_EYEBROW_Y)
			end
		end
	end

	-- ...AND THE DETAIL PANE, IN TALL. 70 px: eyebrow 12 / 6 / track 34 / 6 / caption 12, with its
	-- top where the 14 px status row's top now is -- `layout.statusY` already has the block
	-- subtracted, so the two cannot drift.
	if detailBlock then
		local pane = detailBlock :: Frame
		pane.Visible = surface == "detail"
		pane.Position = UDim2.fromOffset(0, layout.statusY - top)
		pane.Size = UDim2.new(1, 0, 0, PANEL.DETAIL_SWITCH_PX)
		local note = pane:FindFirstChild("RoleCaption") :: TextLabel?
		if note then
			note.Position = UDim2.fromOffset(0, 12 + 6 + PANEL.SWITCH_TRACK_PX + 6)
		end
	end
	if detailSwitch then
		detailSwitch.track.Position = UDim2.fromOffset(0, 12 + 6)
		detailSwitch.track.Size = UDim2.fromOffset(layout.switchTrackWidth, PANEL.SWITCH_TRACK_PX)
	end
	-- THE STATUS LINE AND THE SWITCH ARE NEVER BOTH UP IN THE DETAIL PANE: the block replaces that
	-- row, which is what the 70 px is.
	if status then
		status.Visible = surface ~= "detail"
	end
	ShopPanel.renderRole()
end

-- ---------------------------------------------------------------- the role switch (task 229)

-- WHICH ROLE THE SERVER SAYS HE HAS ASKED FOR, and what side the drive has given him. TOLD, both of
-- them, out of the one evaluation the Hud already runs -- `setPrompt`'s and `Rail.setWeapon`'s rule
-- -- so this panel reads no attribute and holds no opinion about who owns what.
--
-- EDGE-TRIGGERED, and `relayout` is called only when the SURFACE can have changed: a row's height is
-- a rectangle, and `relayout` is this panel's one writer of every rectangle. A `team` that changes
-- repaints and never re-lays-out.
function ShopPanel.setRoleWish(wish: string?, side: string?)
	if type(wish) ~= "string" or (wish ~= ShopPanel.ROLE.HUNTER and wish ~= ShopPanel.ROLE.BEATER) then
		wish = nil
	end
	if type(side) ~= "string" then
		side = nil
	end
	if roleWish == wish and roleTeam == side then
		return
	end
	local was = roleWish
	roleWish = wish
	roleTeam = side
	if (was == nil) ~= (wish == nil) then
		ShopPanel.relayout()
	else
		ShopPanel.renderRole()
	end
end

-- THE LIT HALF AND THE CAPTION, on whichever surface is up. `ShopPanel.paintRoleSwitch` is the one
-- painter of the control itself, so the row and the pad dialog cannot disagree about what
-- "selected" looks like.
function ShopPanel.renderRole()
	local lit = if roleWish == ShopPanel.ROLE.BEATER then ShopPanel.ROLE.BEATER else ShopPanel.ROLE.HUNTER
	if roleWish == nil then
		lit = nil
	end
	local usable = ShopPanel.roleUsable(roleWish, roleTeam)
	local words = spaced(ShopPanel.roleCaptionFor(roleWish, roleTeam))
	for _, pair in ipairs({ { rowSwitch, rowBlock }, { detailSwitch, detailBlock } }) do
		local switch, holder = pair[1], pair[2]
		if switch ~= nil then
			ShopPanel.paintRoleSwitch(switch, lit, usable)
		end
		if holder ~= nil then
			local note = (holder :: Frame):FindFirstChild("RoleCaption") :: TextLabel?
			if note ~= nil and note.Text ~= words then
				note.Text = words
			end
		end
	end
end

-- ONE PRESS, ONE MESSAGE, AND THIS PANEL IS NOT THE SENDER. `Hud.PadPanel` is *"this client's one
-- door onto `ReplicatedStorage.Lobby.Remotes`"*, so it is handed in at `start` as `roleAsk` --
-- exactly as `Cursor` and `Input` are -- which keeps ONE sender on the client and adds no require
-- edge (and in particular no `ShopPanel` -> `PadPanel` edge, which would be a cycle).
function ShopPanel.askRole(which: string): boolean
	if not ShopPanel.roleUsable(roleWish, roleTeam) or roleAsk == nil then
		stats.roleBlocked += 1
		return false
	end
	(roleAsk :: (string) -> ())(which)
	stats.roleSent += 1
	return true
end

function ShopPanel.roleWish(): string?
	return roleWish
end

-- WHICH HALF IS LIT, off the BUILT control rather than off the value it was told -- so a spec can
-- tell "the panel knows" from "the panel drew it". The row's surface first, the detail pane's
-- second; nil when neither is up.
function ShopPanel.roleLit(): string?
	if rowBlock ~= nil and (rowBlock :: Frame).Visible and rowSwitch ~= nil then
		return rowSwitch.selected
	end
	if detailBlock ~= nil and (detailBlock :: Frame).Visible and detailSwitch ~= nil then
		return detailSwitch.selected
	end
	return nil
end

-- WHAT THE BLOCK SAYS, for a spec and for a console probe -- `rowText`'s own seam.
function ShopPanel.switchText(): { string }
	local holder: Frame? = if rowBlock ~= nil and (rowBlock :: Frame).Visible
		then rowBlock
		else (if detailBlock ~= nil and (detailBlock :: Frame).Visible then detailBlock else nil)
	if holder == nil then
		return {}
	end
	local switch = if holder == rowBlock then rowSwitch else detailSwitch
	local brow = (holder :: Frame):FindFirstChild("RoleEyebrow") :: TextLabel?
	local note = (holder :: Frame):FindFirstChild("RoleCaption") :: TextLabel?
	return {
		if brow then brow.Text else "",
		switch.words[ShopPanel.ROLE.HUNTER].Text,
		switch.words[ShopPanel.ROLE.BEATER].Text,
		if note then note.Text else "",
	}
end

-- ---------------------------------------------------------------- drawing

-- THE ROW AND THE CARD WEAR THE SAME STATE, written once here so the two layouts cannot disagree.
local function paintTag(holder: Instance, text: string, kind: string)
	local chip = holder:FindFirstChild("Tag") :: Frame?
	if chip == nil then
		return
	end
	local body = chip:FindFirstChild("TagText") :: TextLabel?
	chip.Visible = text ~= ""
	if body then
		body.Text = text
		body.TextColor3 = TAG_COLOR[kind] or LOOK.FAINT
	end
	chip.BackgroundColor3 = TAG_FILL[kind] or LOOK.LINE
	local edge = chip:FindFirstChildOfClass("UIStroke")
	if edge then
		edge.Color = TAG_FILL[kind] or LOOK.LINE
	end
end

function ShopPanel.render(now: number?)
	local root = panel
	if root == nil then
		return
	end
	stats.renders += 1
	local state = payload
	local hunts = state and state.hunts
	local balance = state and state.balance
	if coinsValue then
		(coinsValue :: TextLabel).Text = ShopPanel.coinsTextFor(state)
	end
	if huntsValue then
		(huntsValue :: TextLabel).Text = ShopPanel.huntsTextFor(state)
	end

	local wire = (state and state.rows) or {}
	local byId: { [string]: any } = {}
	for _, row in ipairs(wire) do
		byId[row.id] = row
	end

	-- THE SIDE MENU and THE PHONE'S CARDS, one pass each over the rows that ARRIVED, by id. A row the
	-- payload does not carry is hidden rather than left reading what it said last time.
	for _, entry in ipairs(menu) do
		local row = byId[entry.id]
		local name = entry.row:FindFirstChild("Name") :: TextLabel?
		local price = entry.row:FindFirstChild("Price") :: TextLabel?
		local disc = entry.row:FindFirstChild("PriceCoin") :: Frame?
		local bar = entry.row:FindFirstChild("Bar") :: Frame?
		local edge = entry.row:FindFirstChildOfClass("UIStroke")
		if row == nil then
			entry.row.Visible = false
			continue
		end
		local tagText, tagKind = ShopPanel.tagTextFor(row, hunts, balance)
		if name then
			name.Text = ShopPanel.rowNameFor(row)
			name.TextColor3 = if tagKind == "owned"
				then LOOK.BODY
				else (if tagKind == "locked" then Color3.fromHex("8E887C") else LOOK.PAPER)
		end
		if price then
			price.Text = ShopPanel.rowPriceFor(row)
			price.TextColor3 = if tagKind == "owned"
				then LOOK.FAINT
				else (if tagKind == "locked"
					then Color3.fromHex("8A7A58")
					else (if tagKind == "poor" then LOOK.CLAY else LOOK.COIN_TEXT))
		end
		if disc then
			disc.BackgroundColor3 = if tagKind == "owned"
				then Color3.fromHex("4A463E")
				else (if tagKind == "poor" then LOOK.CLAY else LOOK.BRASS)
		end
		paintTag(entry.row, tagText, tagKind)
		-- THE SELECTED ROW IS THE ONLY ORANGE THING IN THE LIST, re-decided every render out of one
		-- variable, so two rows can never look selected at once.
		local isSelected = entry.id == selected
		entry.row.BackgroundColor3 = if isSelected
			then LOOK.ROW_SELECTED
			else (if tagKind == "locked" then LOOK.ROW_LOCKED else LOOK.ROW)
		if bar then
			bar.Visible = isSelected
		end
		if edge then
			edge.Transparency = if isSelected then 0.45 else 1
		end
		entry.row.Visible = true
	end

	for _, entry in ipairs(cards) do
		local row = byId[entry.id]
		local name = entry.card:FindFirstChild("Name") :: TextLabel?
		local price = entry.card:FindFirstChild("Price") :: TextLabel?
		local disc = entry.card:FindFirstChild("PriceCoin") :: Frame?
		local edge = entry.card:FindFirstChildOfClass("UIStroke")
		if row == nil then
			entry.card.Visible = false
			continue
		end
		local tagText, tagKind = ShopPanel.tagTextFor(row, hunts, balance)
		if name then
			name.Text = ShopPanel.rowNameFor(row)
		end
		-- AN OWNED CARD SHOWS THE WORD WHERE THE PRICE WAS: *"the price of a thing you own is not
		-- news"* (spec 3.4).
		local owned = tagKind == "owned"
		if price then
			price.Text = if owned then "" else ShopPanel.rowPriceFor(row)
			price.Visible = not owned
			price.TextColor3 = if tagKind == "poor" then LOOK.CLAY else LOOK.COIN_TEXT
		end
		if disc then
			disc.Visible = not owned
			disc.BackgroundColor3 = if tagKind == "poor" then LOOK.CLAY else LOOK.BRASS
		end
		paintTag(entry.card, tagText, tagKind)
		local isSelected = entry.id == selected
		entry.card.BackgroundColor3 = if isSelected then LOOK.ROW_SELECTED else LOOK.ROW
		if edge then
			edge.Color = if isSelected then LOOK.BLAZE else LOOK.WELL_EDGE
			edge.Transparency = if isSelected then 0.25 else 0
		end
		entry.card.Visible = true
	end

	-- THE DETAIL COLUMN, OUT OF THE CURRENT PAYLOAD AND NEVER OUT OF WHAT WAS TRUE WHEN THE ROW WAS
	-- CLICKED. That is what makes the big button honest while the panel is open.
	local row = ShopPanel.rowFor(selected)
	local group = if row ~= nil then (ShopData.CATEGORY_LABEL :: any)[row.category] else nil
	if eyebrowLabel then
		(eyebrowLabel :: TextLabel).Text = if group ~= nil then spaced(tostring(group)) else ""
	end
	if nameLabel then
		(nameLabel :: TextLabel).Text = if row then ShopPanel.rowNameFor(row) else TEXT.PICK
	end
	if priceLabel then
		(priceLabel :: TextLabel).Text = if row then ShopPanel.rowPriceFor(row) else ""
	end
	if priceCaption then
		(priceCaption :: TextLabel).Visible = row ~= nil
	end
	if priceCoin then
		(priceCoin :: Frame).Visible = row ~= nil
	end
	if blurbLabel then
		(blurbLabel :: TextLabel).Text = if row then tostring(row.blurb) else ""
	end

	local clock = now or os.clock()
	if statusLabel then
		(statusLabel :: TextLabel).Text = ShopPanel.statusFor(message, messageAt, clock)
		local tint = ShopPanel.statusColorFor(message, messageKind, messageAt, clock);
		(statusLabel :: TextLabel).TextColor3 = tint
		if statusDot then
			(statusDot :: Frame).BackgroundColor3 = tint
		end
	end

	ShopPanel.paintButton(ShopPanel.buttonStateFor(row, hunts, balance))
end

-- THE BUTTON, PAINTED FROM ITS STATE. One function, seven states, and the word and the amount are
-- child labels so the whole thing is read by `detailText` rather than guessed at.
function ShopPanel.paintButton(state: ButtonState)
	local made = buyButton
	if made == nil then
		return
	end
	local kind = state.kind
	local live = kind == "buy"
	if buyWord then
		(buyWord :: TextLabel).Text = state.word;
		(buyWord :: TextLabel).TextSize = if live then 17 else 15
	end
	if buyAmount then
		(buyAmount :: TextLabel).Text = state.amount or ""
		(buyAmount :: TextLabel).Visible = state.amount ~= nil
	end
	if buyCoin then
		(buyCoin :: Frame).Visible = state.amount ~= nil
	end
	if buyDivider then
		(buyDivider :: Frame).Visible = state.amount ~= nil
	end
	if buyTick then
		(buyTick :: Frame).Visible = kind == "owned"
	end
	if buyHighlight then
		(buyHighlight :: Frame).Visible = live
	end
	if buyGradient then
		(buyGradient :: UIGradient).Enabled = live
	end
	if buyProgress then
		(buyProgress :: Frame).Visible = kind == "locked"
	end
	if buyProgressFill then
		(buyProgressFill :: Frame).Size = UDim2.fromScale(state.progress or 0, 1)
	end

	local fill, edge, text = LOOK.BLAZE, LOOK.BLAZE_EDGE, LOOK.BUTTON_TEXT
	local edgeFade = 0
	if kind == "owned" then
		fill, edge, text, edgeFade = LOOK.PINE_DARK, LOOK.PINE, LOOK.PINE_TEXT, 0.25
	elseif kind == "locked" then
		fill, edge, text, edgeFade = LOOK.AMBER_DARK, LOOK.AMBER_BAR, LOOK.AMBER, 0.5
	elseif kind == "poor" then
		fill, edge, text, edgeFade = LOOK.CLAY_DARK, LOOK.CLAY_EDGE, LOOK.CLAY, 0.5
	elseif kind == "soon" or kind == "none" then
		fill, edge, text, edgeFade = LOOK.SOON_FILL, LOOK.LINE, LOOK.FAINT, 0
	end
	made.BackgroundColor3 = fill
	made.Visible = kind ~= "none"
	if buyStroke then
		(buyStroke :: UIStroke).Color = edge;
		(buyStroke :: UIStroke).Transparency = edgeFade
	end
	if buyWord then
		(buyWord :: TextLabel).TextColor3 = text
	end
	if buyAmount then
		(buyAmount :: TextLabel).TextColor3 = text
	end
end

-- ---------------------------------------------------------------- selection

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

-- ---------------------------------------------------------------- open and close

function ShopPanel.setOpen(next_: boolean)
	if open == next_ then
		return
	end
	open = next_
	local root = panel
	if root then
		root.Visible = open
	end
	if scrim then
		(scrim :: Frame).Visible = open
	end
	if open then
		stats.opens += 1
		-- THE SCREEN MAY HAVE CHANGED SIZE WHILE THE PANEL WAS SHUT: the cheapest place to find out.
		ShopPanel.relayout()
		-- THE MOUSE AND THE TRIGGER, through the two doors that already exist: `Cursor.requestFree`
		-- is what lets him click BUY in first person, and `Input.requestHold` is what stops the same
		-- click firing the gun. Both are reason-keyed, so the shop releases exactly its own request.
		if Cursor ~= nil then
			Cursor.requestFree("shop")
		end
		if WeaponInput ~= nil then
			WeaponInput.requestHold("shop")
		end
		-- SOMETHING IS ALWAYS SELECTED while the panel is open, so the picture and the page are what
		-- the player sees on opening rather than an empty column waiting for a click.
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

-- IS HE AT THE COUNTER? TOLD to this module and never read here -- `Rail.setWeapon`'s stated rule --
-- so there is one reader of the player's position in the Hud and this panel learns nothing about
-- worlds.
--
-- SINCE TASK 181 IT ONLY EVER CLOSES. Walking up to the counter opens nothing: the shopkeeper's
-- prompt is the one way in. Walking away shuts the panel, and the distance it shuts at is
-- `Shop.CONFIG.REACH_STUDS` -- THE SAME NUMBER THE SERVER REFUSES A PURCHASE AT.
--
-- EDGE-TRIGGERED: one write per change, not one per frame.
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

-- THE SHOPKEEPER'S PROMPT, TOLD to this module exactly as `near` is. Anything carrying a `Triggered`
-- signal is accepted -- which is not laxity but the seam that makes the wiring testable at all, since
-- a spec cannot fire a real `ProximityPrompt`.
--
-- EDGE-TRIGGERED ON THE INSTANCE: the same prompt handed in twice does nothing, and a REBUILT lodge
-- drops the old connection rather than leaving this panel listening to a prompt that is no longer in
-- the DataModel.
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
	-- ANY CONNECTION OBJECT, not only an `RBXScriptConnection`: a `BindableEvent` fires DEFERRED, so
	-- a spec driving one could never read the result in the same frame (measured, task 181). The
	-- fake the spec hands in is a plain synchronous signal, and what it drives is this exact line.
	if ok and connection ~= nil then
		promptConnection = connection
		stats.prompts += 1
	else
		prompt = nil
	end
end

function ShopPanel.hasPrompt(): boolean
	return promptConnection ~= nil
end

-- THE FLAG'S VALUE, AND IT IS SETTABLE BECAUSE CLAUDE.md REQUIRES IT TO BE: *"a flagged path must be
-- reachable by parameter as well as by flag"*. `ShopPanel.start` reads `SHOP` once, at the boundary,
-- and this is the same value by another door. Nothing in `src/` calls it.
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
-- open is a prompt you pressed because the panel was in the way of the counter.
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
-- trip for a press on IN YOUR KIT and keeps the panel's voice in one table.
function ShopPanel.pressSelected(): boolean
	local row = ShopPanel.rowFor(selected)
	if row == nil then
		return false
	end
	if row.buyable ~= true then
		local state = payload
		message = ShopPanel.buttonStateFor(row, state and state.hunts, state and state.balance).word
		messageKind = "refused"
		messageAt = os.clock()
		ShopPanel.render()
		return false
	end
	return ShopPanel.press(row.id)
end

-- WHAT THE SERVER SAID. Kept WHOLE and never edited: it is the only thing that changes what this
-- panel believes about his money and his things.
--
-- IT RENDERS WHETHER OR NOT THE PANEL IS OPEN: the payload decides every word on screen, so a panel
-- that kept the old drawing while holding a new payload would show a stale price for one frame after
-- the next open.
function ShopPanel.onState(state: any, now: number?)
	if type(state) ~= "table" then
		return
	end
	stats.states += 1
	payload = state
	if state.bought ~= nil then
		local row = ShopData.row(state.bought)
		message = string.format(TEXT.BOUGHT, if row then row.label else tostring(state.bought))
		messageKind = "bought"
		messageAt = now or os.clock()
	elseif state.refused ~= nil then
		message = ShopData.noticeFor(state.refused, state.refusedNumber)
		messageKind = "refused"
		messageAt = now or os.clock()
	end
	if selected == nil then
		ShopPanel.select(firstId())
	end
	ShopPanel.render(now)
end

function ShopPanel.start(root: Frame, collaborators: any)
	if started then
		return
	end
	started = true
	Cursor = collaborators and collaborators.Cursor
	WeaponInput = collaborators and collaborators.Input
	remotes = collaborators and collaborators.remotes
	-- THE ONE CLIENT SENDER OF A ROLE ASK (task 229), handed in like `Cursor` and `Input` and never
	-- captured: `Hud.start` binds it to `PadPanel.sendRoleWish`, which is this client's one door onto
	-- `ReplicatedStorage.Lobby.Remotes`. nil means no sender, and then a press is counted and
	-- discarded rather than throwing.
	roleAsk = collaborators and collaborators.roleAsk
	-- THE FLAG, READ AT THIS BOUNDARY AND PASSED INWARD (CLAUDE.md, feature flags). `enabled = false`
	-- means `setNear` never opens anything, which is the game before task 178 -- and both branches
	-- stay reachable by parameter, which is what a spec drives.
	enabled = if collaborators ~= nil and collaborators.enabled ~= nil
		then collaborators.enabled == true
		else ShopData.isOn()
	build(root)
	root.Visible = false
	if remotes ~= nil then
		remotes.ShopState.OnClientEvent:Connect(function(state)
			ShopPanel.onState(state)
		end)
	end
end

return ShopPanel
