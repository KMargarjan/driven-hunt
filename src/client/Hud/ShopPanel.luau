--!strict
-- Hud.ShopPanel: THE ONE WRITER of everything inside the `ShopPanel` frame -- **including its
-- `Visible`** -- the one binder of the `DrivenHunt.Shop.*` action, and this client's one door onto
-- `ReplicatedStorage.Shop.Remotes` (CLAUDE.md rule 3).
--
-- KAREN, 2026-10-13: *"Hunting house where inside can shop things"*. So: walk up to the counter task
-- 177 built inside the lodge and this opens; walk away and it closes.
--
-- THE FRAME IS NOT ITS OWN. `Hud.build` creates it with the rest of the screen -- one ScreenGui,
-- built once, so a visibility audit has one place to look -- and this module fills it. It owns the
-- `Visible`, which is the `MapUi` arrangement and not the compass's: whether the shop is open is a
-- thing the player and the counter decide, and the Hud has no second opinion about it.
--
-- IT DRAWS WHAT ARRIVED AND DECIDES NOTHING. Every word, every price and the `buyable` of every row
-- is computed ONCE, on the server, by the pure `Shop.rowsFor`, and arrives as a `WireRow`. The rule
-- `ReportPanel` already states (*"IT DRAWS WHAT ARRIVED AND COMPUTES NOTHING ... so two clients can
-- never disagree"*), and here it is also the security of the thing: a client that could decide it
-- owned something would be a client that could grant itself a rifle.
--
-- IT HOLDS FOUR PIECES OF STATE AND IS THE ONLY WRITER OF ALL FOUR: `open`, `payload`, `message`,
-- `near`.
--
-- IT OWNS THE CLIENT SIDE OF THE REMOTE, which is the one thing `ReportPanel` does not (that panel
-- reads `PlayerScripts.Report`, a replica the Hud's kill feed shares). Nothing else on this client
-- wants the shop's wire, and the Hud already owns a remote connection of its own for exactly that
-- reason (`Hud.onHitMarker` on `Shotgun.Remotes.HitMarker`). A second module holding one
-- `OnClientEvent` would be a system with one caller.
--
--   TextButton           https://create.roblox.com/docs/reference/engine/classes/TextButton
--   GuiButton.Activated  https://create.roblox.com/docs/reference/engine/classes/GuiButton#Activated
--     one event for a click AND a tap, which is why this panel needs no touch branch at all
--     (`Hud.Rail`'s own citation).
--
-- Design: docs/design/shop.md (section 5)
-- Note:   docs/research/2026-10-14-the-shop.md
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Drive = require(ReplicatedStorage:WaitForChild("Drive"))
local ShopData = require(ReplicatedStorage:WaitForChild("Shop"))

local ShopPanel = {}

local CONFIG = ShopData.CONFIG
local PANEL = CONFIG.PANEL
local TEXT = CONFIG.TEXT

-- The reserved prefix, the convention GAME_DESIGN.md's *Input* row sets out and
-- `DrivenHunt.Report.*` follows: a grep for "DrivenHunt.Shop." finds every binding this module owns.
local TOGGLE = "DrivenHunt.Shop.Toggle"

-- `E` IS FREE: the only keys bound in `src/` are Tab (the report), R and X (the weapon), M (the map)
-- and Backspace / Return / the arrows (the report panel). It is bound ONLY WHILE HE IS AT THE
-- COUNTER, so it can never collide with a key a later task wants.
local TOGGLE_KEY = Enum.KeyCode.E

-- ---------------------------------------------------------------- the pixels this module owns
--
-- Every number here is a PIXEL, and pixels are the panel's only arithmetic. The widths, the row
-- height and the Z come from `Shop.CONFIG.PANEL` because both sides read that table; these are the
-- ones nothing outside this file needs.
local PAD = 12
local BUTTON_W = 104
local TITLE_SIZE = 18
local TEXT_SIZE = 14
local Z = PANEL.Z_INDEX

ShopPanel.LOOK = {
	-- The report panel's own colour and its opacity, for the same MEASURED reason: the first frame of
	-- that panel was taken over a sunlit forest and the trees read straight through the text
	-- (`Report.CONFIG.PANEL_TRANSPARENCY`'s comment). A shop is a thing you stop and read.
	PANEL_COLOR = Color3.fromRGB(26, 29, 32),
	ROW_COLOR = Color3.fromRGB(40, 43, 46),
	BUY_COLOR = Color3.fromRGB(42, 86, 48), -- hunting green: the button you may press
	RIM_COLOR = Color3.fromRGB(230, 230, 230),
	COIN_COLOR = Color3.fromRGB(255, 232, 150), -- the cream the board highlights your own row with
	-- How long a refusal stays on screen. The Hud's feed lines live 6 s; a line you caused by
	-- pressing a button needs less.
	MESSAGE_SECONDS = 4,
}

-- ---------------------------------------------------------------- state (four values, one writer)
local open = false
local near = false
local payload: any = nil
local message: string? = nil
local messageAt = -math.huge

local started = false
local bound = false
local panel: Frame? = nil
local title: TextLabel? = nil
local balance: TextLabel? = nil
local footer: TextLabel? = nil
local rows: { Frame } = {}
local remotes: any = nil
local Cursor: any = nil
local WeaponInput: any = nil
local enabled = true

local stats = { opens = 0, closes = 0, asks = 0, presses = 0, sent = 0, states = 0, renders = 0 }

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

-- WHAT IS ACTUALLY ON SCREEN, row by row -- `ReportPanel.rowText`'s rule: the seam a client spec
-- reads instead of guessing. Task 159's lesson in one function (*"the panel reads, the words do
-- not"*).
function ShopPanel.rowText(): { string }
	local out = {}
	for _, row in ipairs(rows) do
		if row.Visible then
			local label = row:FindFirstChild("Text")
			local button = row:FindFirstChild("Buy")
			table.insert(
				out,
				string.format(
					"%s|%s",
					if label and label:IsA("TextLabel") then label.Text else "",
					if button and button:IsA("TextButton") then button.Text else ""
				)
			)
		end
	end
	return out
end

-- ---------------------------------------------------------------- the picture, built once

-- EVERY CHILD SITS ABOVE THE PANEL'S OWN ZINDEX, and task 124's measured defect is why: with the
-- panel opaque at ZIndex 10 and its labels at the default 1, the whole report came out as an EMPTY
-- BLACK RECTANGLE -- the text was being drawn BEHIND its own background.
local function label(parent: Instance, name: string, size: number, position: UDim2, width: number): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.ZIndex = Z + 1
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

-- A BUTTON A THUMB CAN HIT: `Shop.CONFIG.BUTTON_PX` (48) tall, over the 44 px Roblox's own tutorial
-- sets as the minimum, and driven by `Activated` -- one event for a click AND a tap.
local function button(parent: Instance, name: string, width: number): TextButton
	local made = Instance.new("TextButton")
	made.Name = name
	made.AutoButtonColor = false
	made.BackgroundColor3 = ShopPanel.LOOK.ROW_COLOR
	made.BorderSizePixel = 0
	made.Font = Enum.Font.Code
	made.TextSize = TEXT_SIZE
	made.TextColor3 = Drive.CONFIG.TEXT_COLOR
	made.Text = ""
	made.Size = UDim2.fromOffset(width, CONFIG.BUTTON_PX)
	made.ZIndex = Z + 2
	local rim = Instance.new("UIStroke")
	rim.Thickness = 1
	rim.Color = ShopPanel.LOOK.RIM_COLOR
	rim.Transparency = 0.5
	rim.Parent = made
	made.Parent = parent
	return made
end

-- HOW TALL THE WHOLE PANEL IS, for however many rows the catalogue has. PURE, so the rectangle is a
-- spec and not a screenshot.
function ShopPanel.heightFor(count: number): number
	local body = if count <= 0 then 0 else count * PANEL.ROW_PX + (count - 1) * PANEL.GAP
	return PANEL.HEADER_PX + body + PANEL.FOOTER_PX
end

local function build(frame: Frame)
	panel = frame
	local width = PANEL.WIDTH
	title = label(frame, "Title", TITLE_SIZE, UDim2.fromOffset(PAD, 8), width - 2 * PAD - BUTTON_W);
	(title :: TextLabel).Text = TEXT.TITLE

	-- THE CLOSE BUTTON, and it is not a nicety: on a touch device it is the only way out of this
	-- panel, because `Escape` belongs to the Roblox menu and cannot be bound (`ReportPanel.bind`'s
	-- own note). Walking away from the counter closes it too.
	local close = button(frame, "Close", BUTTON_W)
	close.Text = TEXT.CLOSE
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -PAD, 0, 6)
	close.Activated:Connect(function()
		ShopPanel.setOpen(false)
	end)

	balance = label(frame, "Balance", TEXT_SIZE, UDim2.fromOffset(PAD, 8 + TITLE_SIZE + 8), width - 2 * PAD);
	(balance :: TextLabel).TextColor3 = ShopPanel.LOOK.COIN_COLOR

	table.clear(rows)
	for index = 1, CONFIG.MAX_ITEMS do
		local row = Instance.new("Frame")
		row.Name = string.format("Row%d", index)
		row.BackgroundColor3 = ShopPanel.LOOK.ROW_COLOR
		row.BackgroundTransparency = 0.35
		row.BorderSizePixel = 0
		row.Position = UDim2.fromOffset(PAD, PANEL.HEADER_PX + (index - 1) * (PANEL.ROW_PX + PANEL.GAP))
		row.Size = UDim2.fromOffset(width - 2 * PAD, PANEL.ROW_PX)
		row.Visible = false
		row.ZIndex = Z + 1
		row.Parent = frame
		local textWidth = width - 2 * PAD - BUTTON_W - 16
		label(row, "Text", TEXT_SIZE, UDim2.fromOffset(8, 4), textWidth)
		local gate = label(row, "Gate", TEXT_SIZE - 3, UDim2.fromOffset(8, 24), textWidth)
		gate.TextTransparency = 0.3
		local buy = button(row, "Buy", BUTTON_W)
		buy.AnchorPoint = Vector2.new(1, 0.5)
		buy.Position = UDim2.new(1, -8, 0.5, 0)
		-- THE INDEX IS CLOSED OVER AND THE ITEM IS READ AT PRESS TIME, so a row drawing a different
		-- item after a redraw cannot buy the one it used to show.
		buy.Activated:Connect(function()
			ShopPanel.pressRow(index)
		end)
		table.insert(rows, row)
	end

	footer = label(
		frame,
		"Footer",
		TEXT_SIZE,
		UDim2.fromOffset(PAD, ShopPanel.heightFor(#ShopData.ORDER) - PANEL.FOOTER_PX + 8),
		width - 2 * PAD
	)
end

-- ---------------------------------------------------------------- the words, pure and exported

-- PURE and exported for `ReportPanel.listRowText`'s reason: what the panel SAYS has to be a spec
-- rather than a screenshot. 30 characters at `TextSize = 14` in `Enum.Font.Code`, which is what
-- fits the 360 px panel (design section 13.1).
function ShopPanel.rowLabelFor(row: any): string
	if row == nil then
		return ""
	end
	return string.format("%-18s %5d", string.sub(tostring(row.label), 1, 18), row.price)
end

-- THE SECOND LINE OF A ROW: why he cannot have it, or what it does. It is the row's own `WireRow`
-- read out loud, so the server's decision is the only thing on screen.
function ShopPanel.rowGateFor(row: any): string
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

-- THE WORD ON THE BUTTON. `buyable` is the ONE field it reads -- computed once, on the server -- so
-- a greyed-out button and an accepted purchase cannot disagree (design hazard 10).
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

-- ---------------------------------------------------------------- drawing

function ShopPanel.render(now: number?)
	local frame = panel
	if frame == nil then
		return
	end
	stats.renders += 1
	local state = payload;
	(balance :: TextLabel).Text = ShopPanel.balanceLineFor(state)
	local wire = (state and state.rows) or {}
	for index, row in ipairs(rows) do
		local item = wire[index]
		if item == nil then
			row.Visible = false
			continue
		end
		local text = row:FindFirstChild("Text") :: TextLabel?
		local gate = row:FindFirstChild("Gate") :: TextLabel?
		local buy = row:FindFirstChild("Buy") :: TextButton?
		if text then
			text.Text = ShopPanel.rowLabelFor(item)
		end
		if gate then
			gate.Text = ShopPanel.rowGateFor(item)
		end
		if buy then
			buy.Text = ShopPanel.buttonTextFor(item)
			-- GREEN IS THE ONE YOU MAY PRESS. A locked rung of the ladder is still DRAWN, because it
			-- is information -- Karen's ladder has four rungs and a shop that hid one would tell her
			-- it is shorter than it is.
			buy.BackgroundColor3 = if item.buyable == true then ShopPanel.LOOK.BUY_COLOR else ShopPanel.LOOK.ROW_COLOR
		end
		row.Visible = true
	end
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

function ShopPanel.toggle()
	ShopPanel.setOpen(not open)
end

-- ---------------------------------------------------------------- the counter

local function bind()
	if bound then
		return
	end
	bound = true
	ContextActionService:BindAction(TOGGLE, function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			ShopPanel.toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, TOGGLE_KEY)
end

local function unbind()
	if not bound then
		return
	end
	bound = false
	ContextActionService:UnbindAction(TOGGLE)
end

-- IS HE AT THE COUNTER? TOLD to this module and never read here -- `Rail.setWeapon`'s stated rule
-- (*"`hasWeapon` is TOLD to this module by the Hud, never read here"*), so there is one reader of
-- the player's position in the Hud and this panel learns nothing about worlds.
--
-- EDGE-TRIGGERED: one write per change, not one per frame, which is `Lobby`'s own discipline for an
-- attribute that used to be written fifty times per walk-in.
function ShopPanel.setNear(next_: boolean)
	next_ = next_ == true and enabled
	if near == next_ then
		return
	end
	near = next_
	if near then
		bind()
		if CONFIG.AUTO_OPEN then
			ShopPanel.setOpen(true)
		end
	else
		unbind()
		ShopPanel.setOpen(false)
	end
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

function ShopPanel.pressRow(index: number): boolean
	local wire = payload and payload.rows
	local row = if wire then wire[index] else nil
	if row == nil then
		return false
	end
	-- A ROW THE SERVER DREW AS DEAD IS NOT SENT, and the line it would have refused with is printed
	-- from the SAME `WireRow` instead. The server is still the only thing that decides -- this saves
	-- a round trip for a press on "OWNED" and keeps the footer's voice in one table.
	if row.buyable ~= true then
		message = ShopPanel.rowGateFor(row)
		messageAt = os.clock()
		ShopPanel.render()
		return false
	end
	return ShopPanel.press(row.id)
end

-- WHAT THE SERVER SAID. Kept WHOLE and never edited: it is the only thing that changes what this
-- panel believes about his money and his things.
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
	if open then
		ShopPanel.render(now)
	end
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
