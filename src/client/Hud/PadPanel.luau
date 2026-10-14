--!strict
-- Hud.PadPanel: THE ONE WRITER of everything inside the `PadPanel` frame -- **including its
-- `Visible`** -- and this client's one door onto `ReplicatedStorage.Lobby.Remotes` (CLAUDE.md rule 3).
--
-- KAREN, 2026-10-14 ~09:30: *"you come to truck back rectangle and can click and select how many
-- players ... can be 1/1 or 4/4 you can select on dialiog how many like in roblox games"*.
--
-- SO: step onto an empty truck pad, this asks how many, and a party of that size leaves together.
--
-- IT OPENS BECAUSE THE SERVER ASKED, AND FOR NO OTHER REASON. The server writes two attributes on
-- the PAD'S OWN PART -- `DHPadState` and `DHPadFirst` -- and `Lobby.padAsking(userId)` turns the four
-- pads into one answer: which pad, if any, is asking THIS player to pick. The Hud reads that on the
-- evaluation it already runs and TELLS this module the number (`Rail.setWeapon`'s rule:
-- *"`hasWeapon` is TOLD to this module by the Hud, never read here"*). So the dialog's visibility is
-- a SERVER-MEASURED fact, and this panel learns nothing about worlds, rectangles or who is first --
-- which is also the security of it, because a panel that could decide it was the first man on a pad
-- would be a client that could put eight strangers in a truck.
--
-- STEPPING OFF CLOSES IT, and that is the same two attributes changing: the server's own cancel, not
-- a second rule on this side. Karen asked for exactly that -- the dialog is a choice, and walking
-- away is how you decline it.
--
-- NO CLOSE BUTTON, AND THAT IS DELIBERATE. `ShopPanel` needs one because walking away is the only
-- other way out of it and `Escape` belongs to the Roblox menu (`ReportPanel.bind`'s note). Here
-- there are five exits: the four buttons, and stepping off the pad. **`1 / 1  alone` IS the "leave me
-- alone" button**, and it is also what the eight-second timeout does by itself, so this dialog can
-- never be a dead end or a gate you must pass to play.
--
-- THE FRAME IS NOT ITS OWN. `Hud.build` creates it with the rest of the screen -- one ScreenGui,
-- built once, so a visibility audit has one place to look -- and this module fills it. It owns the
-- `Visible`, which is the `MapUi` / `ShopPanel` arrangement: whether the dialog is up is a thing the
-- server and the pad decide, and the Hud has no second opinion about it.
--
-- IT HOLDS TWO PIECES OF STATE AND IS THE ONLY WRITER OF BOTH: `ask` (which pad is asking, or nil)
-- and `sent` (the size this client has already asked for, so a double tap is one message).
--
-- IT DRAWS WHAT ARRIVED AND DECIDES NOTHING. The four rows are `Lobby.CONFIG.PADS.SIZES`, read from
-- the shared table both sides read, labels and all -- `ReportPanel`'s rule (*"IT DRAWS WHAT ARRIVED
-- AND COMPUTES NOTHING"*).
--
--   TextButton           https://create.roblox.com/docs/reference/engine/classes/TextButton
--   GuiButton.Activated  https://create.roblox.com/docs/reference/engine/classes/GuiButton#Activated
--     one event for a click AND a tap, which is why this panel needs no touch branch at all
--     (`Hud.Rail`'s and `ShopPanel`'s own citation). `PANEL.BUTTON_PX` is 48, over the 44 px
--     Roblox's own tutorial sets as a touch minimum.
--
-- Design: docs/design/truck-pads.md (sections 8.1, 10.3)
-- Note:   docs/research/2026-10-14-truck-pads.md (section 5.4)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Drive = require(ReplicatedStorage:WaitForChild("Drive"))
local LobbyData = require(ReplicatedStorage:WaitForChild("Lobby"))

local PadPanel = {}

local PADS = LobbyData.CONFIG.PADS
local PANEL = PADS.PANEL

-- ---------------------------------------------------------------- the pixels this module owns
--
-- Every number here is a PIXEL. The width, the row height, the button height and the Z come from
-- `Lobby.CONFIG.PADS.PANEL` because both sides read that table; these are the ones nothing outside
-- this file needs.
local PAD = 12
local TITLE_SIZE = 19
local LABEL_SIZE = 18

PadPanel.LOOK = {
	-- `ShopPanel.LOOK.PANEL_COLOR`'s own colour and its opacity, for the same MEASURED reason: the
	-- first frame of the report panel was taken over a sunlit forest and the trees read straight
	-- through the text (`Report.CONFIG.PANEL_TRANSPARENCY`'s comment). A dialog is a thing you stop
	-- and read.
	PANEL_COLOR = Color3.fromRGB(26, 29, 32),
	-- `ShopPanel.LOOK.BUY_COLOR`: in this game hunting green means *the button you may press*. The
	-- PAD's own colour is deliberately not used -- this dialog belongs to the SCREEN and the pads
	-- belong to the WORLD, so a panel tinted like pad 3 would be claiming to be part of pad 3.
	BUTTON_COLOR = Color3.fromRGB(42, 86, 48),
	RIM_COLOR = Color3.fromRGB(230, 230, 230),
}

-- ---------------------------------------------------------------- state (two values, one writer)
local ask: number? = nil
local sent: number? = nil

local started = false
local panel: Frame? = nil
local title: TextLabel? = nil
local buttons: { TextButton } = {}
local remotes: any = nil
local Cursor: any = nil
local WeaponInput: any = nil

local stats = { opens = 0, closes = 0, presses = 0, sent = 0, renders = 0 }

function PadPanel.stats()
	return table.clone(stats)
end

function PadPanel.isOpen(): boolean
	return ask ~= nil
end

function PadPanel.padIndex(): number?
	return ask
end

function PadPanel.frame(): Frame?
	return panel
end

function PadPanel.titleText(): string
	return if title then (title :: TextLabel).Text else ""
end

-- WHAT IS ACTUALLY ON SCREEN, row by row -- `ShopPanel.rowText`'s seam: what a client spec reads
-- instead of guessing. Task 159's lesson in one function (*"the panel reads, the words do not"*).
function PadPanel.rowText(): { string }
	local out = {}
	for _, button in ipairs(buttons) do
		if button.Visible then
			table.insert(out, button.Text)
		end
	end
	return out
end

-- ---------------------------------------------------------------- the rectangle, pure and exported

-- HOW TALL THE WHOLE DIALOG IS, for however many sizes the data lists. PURE, so the rectangle is a
-- spec and not a screenshot -- `ShopPanel.heightFor`'s rule, and `Hud.build` sizes the frame with it
-- so ONE number decides both the rows and the box (the Reviewer's task-178 round-1 note: they used to
-- be two, and a sixth row would have been drawn outside the frame in silence).
function PadPanel.heightFor(count: number?): number
	local rows = count or #PADS.SIZES
	local body = if rows <= 0 then 0 else rows * PANEL.ROW_PX + (rows - 1) * PANEL.GAP
	return PANEL.HEADER_PX + body + PAD
end

function PadPanel.widthFor(): number
	return PANEL.WIDTH
end

function PadPanel.zIndex(): number
	return PANEL.Z_INDEX
end

-- ---------------------------------------------------------------- the picture, built once

local function build(frame: Frame)
	panel = frame
	local width = PANEL.WIDTH

	local head = Instance.new("TextLabel")
	head.Name = "Title"
	-- EVERY CHILD SITS ABOVE THE PANEL'S OWN ZINDEX, and task 124's measured defect is why: with the
	-- panel opaque and its labels at the default 1, the whole report came out as an EMPTY BLACK
	-- RECTANGLE -- the text was being drawn BEHIND its own background.
	head.ZIndex = PANEL.Z_INDEX + 1
	head.BackgroundTransparency = 1
	head.Font = Enum.Font.Code
	head.TextSize = TITLE_SIZE
	head.TextColor3 = Drive.CONFIG.TEXT_COLOR
	head.Text = PANEL.TITLE
	head.Position = UDim2.fromOffset(PAD, 12)
	head.Size = UDim2.fromOffset(width - 2 * PAD, TITLE_SIZE + 6)
	head.TextXAlignment = Enum.TextXAlignment.Left
	-- THE SAME BLACK OUTLINE every other label in this Hud wears: over a bright field a thin `Code`
	-- glyph with no stroke is the half of the text that disappears first.
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = head
	head.Parent = frame
	title = head

	table.clear(buttons)
	for index, row in ipairs(PADS.SIZES) do
		local button = Instance.new("TextButton")
		button.Name = string.format("Size%d", row.size)
		button.AutoButtonColor = false
		button.BackgroundColor3 = PadPanel.LOOK.BUTTON_COLOR
		button.BorderSizePixel = 0
		button.Font = Enum.Font.Code
		button.TextSize = LABEL_SIZE
		button.TextColor3 = Drive.CONFIG.TEXT_COLOR
		-- THE LABEL IS THE DATA'S OWN, not a format applied here: Karen wrote `1 / 1` and `4 / 4`
		-- herself, and the two ends of the range carry a word so four numbers read as a choice.
		button.Text = row.label
		button.Position = UDim2.fromOffset(PAD, PANEL.HEADER_PX + (index - 1) * (PANEL.ROW_PX + PANEL.GAP))
		button.Size = UDim2.fromOffset(width - 2 * PAD, PANEL.BUTTON_PX)
		button.ZIndex = PANEL.Z_INDEX + 2
		local rim = Instance.new("UIStroke")
		rim.Thickness = 1
		rim.Color = PadPanel.LOOK.RIM_COLOR
		rim.Transparency = 0.5
		rim.Parent = button
		-- THE SIZE IS CLOSED OVER AND THE PAD IS READ AT PRESS TIME, so a dialog that has re-opened
		-- for a different pad cannot send a pick for the one it used to show (`ShopPanel`'s
		-- `buy.Activated` rule).
		button.Activated:Connect(function()
			PadPanel.press(row.size)
		end)
		button.Parent = frame
		table.insert(buttons, button)
	end
end

-- ---------------------------------------------------------------- the one thing it is told

-- WHICH PAD IS ASKING THIS PLAYER, or nil. TOLD to this module and never read here.
--
-- EDGE-TRIGGERED: one write per change and not one per frame, which is this repository's discipline
-- for anything a renderer touches (`ShopPanel.setNear`, and `Lobby`'s own `setRespawn` on the server
-- side of the same system).
function PadPanel.setAsk(next_: number?)
	if type(next_) ~= "number" then
		next_ = nil
	end
	if ask == next_ then
		return
	end
	local wasOpen = ask ~= nil
	ask = next_
	-- A NEW PAD IS A NEW QUESTION, so the size this client already sent is forgotten with the old
	-- one: without this, stepping off pad 1 after picking 4 and onto pad 2 would leave the dialog
	-- unable to send anything at all.
	sent = nil
	if ask ~= nil and not wasOpen then
		stats.opens += 1
		-- THE MOUSE AND THE TRIGGER, through the two doors that already exist: `Cursor.requestFree`
		-- is what lets him press a button in first person, and `Input.requestHold` is what stops the
		-- same click firing the gun. Both are reason-keyed, so this releases exactly its own request
		-- (`ShopPanel.setOpen`'s shape, tag `"padsize"`).
		if Cursor ~= nil then
			Cursor.requestFree("padsize")
		end
		if WeaponInput ~= nil then
			WeaponInput.requestHold("padsize")
		end
	elseif ask == nil and wasOpen then
		stats.closes += 1
		if Cursor ~= nil then
			Cursor.release("padsize")
		end
		if WeaponInput ~= nil then
			WeaponInput.releaseHold("padsize")
		end
	end
	PadPanel.render()
end

function PadPanel.render()
	stats.renders += 1
	local frame = panel
	if frame == nil then
		return
	end
	frame.Visible = ask ~= nil
	for _, button in ipairs(buttons) do
		-- A SIZE THIS CLIENT HAS ALREADY ASKED FOR IS DIMMED, so a tap that is in flight looks like a
		-- tap that happened. It is COSMETIC: the server decides, and `sent` only ever stops THIS
		-- client sending the same number twice.
		button.TextTransparency = if sent ~= nil then 0.45 else 0
	end
end

-- ---------------------------------------------------------------- the press

-- ONE PRESS, ONE MESSAGE. PUBLIC and named for `Rail.press`'s and `ShopPanel.press`' stated reason:
-- a spec cannot fire `GuiButton.Activated` and the harness cannot synthesise a tap, so this is the
-- seam that makes the buttons testable at all -- and what it proves is the ACTION, not the touch.
-- That limit is reported in the review request, not papered over.
--
-- IT SENDS NOTHING FOR A SIZE THAT IS NOT IN THE DATA. The server refuses one anyway (`bad-request`,
-- counted as a forgery), and a client that sent one would be this client telling the server a lie
-- about its own catalogue.
function PadPanel.press(size: number): boolean
	stats.presses += 1
	local index = ask
	if index == nil or sent == size then
		return false
	end
	local known = false
	for _, row in ipairs(PADS.SIZES) do
		if row.size == size then
			known = true
			break
		end
	end
	if not known then
		return false
	end
	sent = size
	if remotes ~= nil and remotes.PadRequest ~= nil then
		remotes.PadRequest:FireServer({ pad = index, size = size })
		stats.sent += 1
	end
	PadPanel.render()
	return true
end

-- THE REMOTES, TOLD rather than captured at `start`, exactly as `ShopPanel.setPrompt` is told its
-- prompt: `ReplicatedStorage.Lobby` is resolved by `Hud.whenReady`, which may land after `Hud.start`,
-- and a world with no lobby never hands one over at all.
--
-- EDGE-TRIGGERED ON THE TABLE, so this costs one comparison a frame.
function PadPanel.setRemotes(next_: any)
	remotes = next_
end

function PadPanel.start(frame: Frame, collaborators: any)
	if started then
		return
	end
	started = true
	local bag = collaborators or {}
	Cursor = bag.Cursor
	WeaponInput = bag.Input
	remotes = bag.remotes
	build(frame)
	frame.Visible = false
	PadPanel.render()
end

-- THE TEARDOWN A CLIENT SPEC NEEDS: nothing on screen, nothing held, and the two doors handed back.
function PadPanel.stop()
	if ask ~= nil then
		PadPanel.setAsk(nil)
	end
	started = false
	ask = nil
	sent = nil
	table.clear(buttons)
	panel = nil
	title = nil
	remotes = nil
	Cursor = nil
	WeaponInput = nil
end

return PadPanel
