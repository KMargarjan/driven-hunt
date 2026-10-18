--!strict
-- Hud.PadPanel: THE ONE WRITER of everything inside the `PadPanel` frame AND the `PadLeaving` frame
-- -- **including both `Visible`s** -- and this client's one door onto
-- `ReplicatedStorage.Lobby.Remotes` (CLAUDE.md rule 3).
--
-- KAREN, 2026-10-14 ~09:30: *"you come to truck back rectangle and can click and select how many
-- players ... can be 1/1 or 4/4 you can select on dialiog how many like in roblox games"*.
--
-- SO: step onto an empty truck pad, this asks how many, and a party of that size leaves together.
--
-- KAREN, 2026-10-15 ~17:40, verbatim: *"same with entering in game menu has to be nicer and cleaner
-- / and we need clear message that game is loading once clicked 1/1 or other now is delay / also
-- could be car started sound light on something like that indicating loading ect"*.
--
-- SO TASK 197 GIVES THIS MODULE TWO THINGS MORE: the dialog is redrawn in the SHOP'S HOUSE STYLE,
-- and the five seconds after a pick are a BANNER across the screen instead of nothing.
--
-- WHY THE BANNER IS THIS MODULE'S AND NOT A NEW ONE. It is the second half of one question -- *"how
-- many, and then what"* -- it is driven by the same pad state machine, it needs the same mouse and
-- trigger doors released, and the two can never be on screen together (the dialog needs `sizing` and
-- the banner needs one of the three states after it). A second module would be a second reader of
-- the same two facts, which is this repository's named failure mode (`docs/PROJECT_CONTEXT.md`).
--
-- THE STYLE IS THE SHOP'S, AND NOT A SECOND COPY OF IT. `Hud.ShopPanel.LOOK`, `.FONT` and `.spaced`
-- are read straight out of that module -- *"The shop sets the house style. Anything built after it
-- follows these, and nothing else needs deciding"* (the designer's spec section 8, written for
-- exactly this menu and this loading line, and the style Karen has already looked at: *"menu is
-- nice"*). Forty hexes and five font families copied into this file would be forty-five second
-- answers.
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
-- AND THE BANNER IS THE SAME SHAPE: one attribute on the PLAYER, `DHPadMine`, holding the state word
-- of the pad he is loading onto, written only by the owner and read-only here. A client cannot work
-- that out for itself -- after the pick there is no `DHPadFirst` for him and no client-side answer to
-- *"which of the four rectangles am I standing on"* -- and a client copy of `Pads.indexAt` would be a
-- second answer to a question the server already measures.
--
-- STEPPING OFF CLOSES IT, and that is the same attributes changing: the server's own cancel, not
-- a second rule on this side. Karen asked for exactly that -- the dialog is a choice, and walking
-- away is how you decline it.
--
-- NO CLOSE BUTTON, AND THAT IS DELIBERATE. `ShopPanel` needs one because walking away is the only
-- other way out of it and `Escape` belongs to the Roblox menu (`ReportPanel.bind`'s note). Here
-- there are five exits: the four buttons, and stepping off the pad. **`1 / 1` IS the "leave me
-- alone" button**, and it is also what the eight-second timeout does by itself, so this dialog can
-- never be a dead end or a gate you must pass to play. Since task 197 the dialog SAYS the other
-- exit, in its one message line (`PANEL.HINT`), because a way out nobody can see is not an exit.
--
-- AND THERE IS NO SCRIM, which is the one place this panel departs from the shop's surface ladder
-- (spec 8.1) -- with a reason rather than by omission. The shop dims the whole screen because its
-- only other way out is a button on it. Stepping OFF THE PAD is one of this dialog's five exits, so
-- dimming the world a player has to walk out of would hide the way out.
--
-- THE FRAMES ARE NOT ITS OWN. `Hud.build` creates both with the rest of the screen -- one ScreenGui,
-- built once, so a visibility audit has one place to look -- and this module fills them. It owns the
-- `Visible` of each, which is the `MapUi` / `ShopPanel` arrangement: whether the dialog is up is a
-- thing the server and the pad decide, and the Hud has no second opinion about it.
--
-- IT HOLDS FOUR PIECES OF STATE AND IS THE ONLY WRITER OF ALL FOUR: `ask` (which pad is asking, or
-- nil), `sent` (the size this client has already asked for, so a double tap is one message),
-- `loading` (the state word of the pad taking him, or nil) and `left` (the seconds the server says
-- are left).
--
-- IT DRAWS WHAT ARRIVED AND DECIDES NOTHING. The four rows are `Lobby.CONFIG.PADS.SIZES`, read from
-- the shared table both sides read, labels and all -- `ReportPanel`'s rule (*"IT DRAWS WHAT ARRIVED
-- AND COMPUTES NOTHING"*).
--
--   TextButton           https://create.roblox.com/docs/reference/engine/classes/TextButton
--   GuiButton.Activated  https://create.roblox.com/docs/reference/engine/classes/GuiButton#Activated
--     one event for a click AND a tap, which is why this panel needs no touch branch at all
--     (`Hud.Rail`'s and `ShopPanel`'s own citation). `PANEL.BUTTON_PX` is 60, over the 44 px
--     Roblox's own tutorial sets as a touch minimum and inside the 48-60 the designer's spec 8.6
--     gives a secondary row.
--
-- Design: docs/design/truck-pads.md (sections 8.1, 10.3)
-- Note:   docs/research/2026-10-14-truck-pads.md (section 5.4)
-- Note:   docs/research/2026-10-17-the-pad-menu-and-the-truck.md (task 197)
-- Style:  the designer's shop spec section 8, outside the repo (`shop-design-spec.md`)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyData = require(ReplicatedStorage:WaitForChild("Lobby"))
-- THE HOUSE STYLE, FROM THE ONE MODULE THAT DEFINES IT. A read of a frozen palette and five `Font`
-- values; `ShopPanel` requires nothing of this module back, so there is no cycle.
local ShopPanel = require(script.Parent.ShopPanel)

local PadPanel = {}

local PADS = LobbyData.CONFIG.PADS
local PANEL = PADS.PANEL
local LEAVING = PADS.LEAVING

local LOOK = ShopPanel.LOOK
local FONT = ShopPanel.FONT
local spaced = ShopPanel.spaced

-- ---------------------------------------------------------------- the pixels this module owns
--
-- Every number here is a PIXEL. The width, the row height, the button height, the header and the Z
-- come from `Lobby.CONFIG.PADS.PANEL` and `.LEAVING` because both sides read those tables; these are
-- the ones nothing outside this file needs.
local PAD = 14
local EYEBROW_SIZE = 9
local TITLE_SIZE = 23
local LABEL_SIZE = 20
local NOTE_SIZE = 12
local HINT_SIZE = 10
local LEAVING_LINE_SIZE = 15
local HAIRLINE_PX = 1
local SELECTED_BAR_PX = 4
local CORNER_PANEL = 16
local CORNER_ROW = 11

PadPanel.LOOK = {
	-- `Hud.build` PAINTS THE FRAME WITH THIS, which is why the panel's own colour is still a field
	-- here and not only a hex in `ShopPanel`: one reader outside this file.
	--
	-- IT IS THE SHOP PANEL'S OWN `#1C1915` NOW, not task 182's blue-grey 26,29,32 -- the same warm
	-- charcoal-brown, for the same measured reason that one was opaque: the first frame of the report
	-- panel was taken over a sunlit forest and the trees read straight through the text
	-- (`Report.CONFIG.PANEL_TRANSPARENCY`'s comment). A dialog is a thing you stop and read.
	PANEL_COLOR = LOOK.PANEL,
	-- A ROW AT REST, and the one orange thing on this screen is the DEFAULT row's left bar (spec 8.4:
	-- *"One orange thing per screen"*). The four sizes are four equal choices, so none of them is a
	-- primary button -- what the orange marks is the row that happens if you do nothing, which is a
	-- fact about the game (`Pads.defaultSize` is row 1) and not a recommendation.
	BUTTON_COLOR = LOOK.ROW,
	ROW_HOVER_COLOR = LOOK.ROW_HOVER,
	RIM_COLOR = LOOK.LINE,
	-- KEPT FOR ONE READER OUTSIDE THIS FILE and otherwise unused: `Hud.build` sets the banner's
	-- background from it.
	LEAVING_COLOR = LOOK.PANEL,
}

-- ---------------------------------------------------------------- state (six values, one writer)
local ask: number? = nil
local sent: number? = nil
local loading: string? = nil
local left: number? = nil
-- THE CLICK THE SERVER HAS NOT ANSWERED YET (task 209). `sentAt` is when this client fired its pick
-- and `shownAt` the clock it was last told, both in the SAME seconds: the Hud hands `setLeaving` an
-- `os.clock()` every frame and this module keeps no clock of its own -- `Pads.step`'s arrangement on
-- the server's side of this system, and what lets `pad_panel.spec` expire the window with a number
-- instead of a `task.wait`.
local sentAt: number? = nil
local shownAt = 0

local started = false
local panel: Frame? = nil
local eyebrow: TextLabel? = nil
local title: TextLabel? = nil
local buttons: { TextButton } = {}
local notes: { TextLabel } = {}
local banner: Frame? = nil
local bannerEyebrow: TextLabel? = nil
local bannerLine: TextLabel? = nil
local bannerTrack: Frame? = nil
local bannerFill: Frame? = nil
local remotes: any = nil
local Cursor: any = nil
local WeaponInput: any = nil

-- `optimistic` IS ONE PER CLICK THAT RAISED THE BANNER BEFORE THE SERVER ANSWERED (task 209), which
-- is what makes *"it shows immediately"* a number a probe can read rather than a claim.
local stats = {
	opens = 0,
	closes = 0,
	presses = 0,
	sent = 0,
	renders = 0,
	leavingOpens = 0,
	leavingCloses = 0,
	barWrites = 0,
	optimistic = 0,
}

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
--
-- IT READS THE ROW'S NAME LABEL AND NOT `TextButton.Text`, because a row is two lines now: the
-- button itself carries no text at all (`Text = ""`, the shop's own big-button arrangement) so the
-- number and the line under it can be set in two different faces at two different sizes.
function PadPanel.rowText(): { string }
	local out = {}
	for _, button in ipairs(buttons) do
		if button.Visible then
			local label = button:FindFirstChild("Label")
			table.insert(out, if label ~= nil and label:IsA("TextLabel") then (label :: TextLabel).Text else "")
		end
	end
	return out
end

-- ...AND THE SHORT LINE UNDER EACH (task 197). The Director: *"big buttons with a short line each"*.
function PadPanel.rowNote(): { string }
	local out = {}
	for _, note in ipairs(notes) do
		table.insert(out, note.Text)
	end
	return out
end

-- ---------------------------------------------------------------- the banner's words, pure

-- WHAT THE LOADING BANNER SAYS, for a state word and a number of seconds. PURE and exported, which
-- is `Objective.text`'s own arrangement: the sentence is a spec and not a screenshot.
--
-- "" FOR ANYTHING THAT IS NOT ONE OF THE THREE LOADING STATES, including nil -- so the one rule that
-- decides whether the banner is up (`Lobby.padLoading`) and the one that decides what it says can
-- never disagree.
function PadPanel.leavingLineFor(state: string?, secondsLeft: number?): string
	local words = LEAVING
	if state == LobbyData.PAD_STATE.FILLING then
		return words.FILLING
	end
	if state == LobbyData.PAD_STATE.COUNTDOWN then
		-- `ceil`, exactly as `Objective.text`'s own countdown does, so "1" is the last whole second
		-- and the line never reads 0 while he is still standing there.
		return string.format(words.COUNTDOWN, math.max(0, math.ceil(secondsLeft or 0)))
	end
	if state == LobbyData.PAD_STATE.LEAVING then
		return words.GOING
	end
	return ""
end

-- HOW FULL THE BAR IS, or nil for "do not draw a bar at all". PURE.
--
-- nil WHILE THE PARTY IS FILLING, AND THAT IS HONESTY RATHER THAN AN OVERSIGHT. In `filling` the pad
-- is waiting for up to `FILL_TIMEOUT_SECONDS` for people who may never come, and the player is told
-- so in words; a bar inching along would be claiming to know how long that is. A bar appears when
-- there IS a deadline -- the countdown -- and is full once the drive is taking him.
function PadPanel.barFraction(state: string?, secondsLeft: number?): number?
	if state == LobbyData.PAD_STATE.COUNTDOWN then
		local whole = LobbyData.CONFIG.COUNTDOWN_SECONDS
		if whole <= 0 then
			return 1
		end
		return math.clamp(1 - (secondsLeft or 0) / whole, 0, 1)
	end
	if state == LobbyData.PAD_STATE.LEAVING then
		return 1
	end
	return nil
end

-- WHAT THE BANNER SAYS WHEN THE SERVER HAS NOT SPOKEN YET. PURE, and it is the ONE place the
-- server's three words and this client's own click meet (task 209).
--
-- THE SERVER WINS WHENEVER IT HAS SAID ANYTHING. `pending` only ever fills the gap between the
-- click and the first `DHPadMine` -- measured at 3.65 s on Karen's own path -- so the banner can
-- never contradict the world: the moment a pad state arrives, `leavingLineFor` answers and this
-- function returns its line unchanged.
function PadPanel.bannerLineFor(state: string?, secondsLeft: number?, pending: boolean?): string
	local line = PadPanel.leavingLineFor(state, secondsLeft)
	if line ~= "" then
		return line
	end
	return if pending == true then LEAVING.SENT else ""
end

-- IS THIS CLIENT'S OWN PICK STILL IN FLIGHT? `sentAt` is cleared by the server's first word, by a
-- new pad asking, and by `PENDING_SECONDS` of silence -- the third being the one that matters, since
-- a pick the server REFUSES produces no word at all and a banner with no way down is worse than a
-- slow one.
local function pendingPick(): boolean
	if sentAt == nil then
		return false
	end
	if shownAt - (sentAt :: number) >= LEAVING.PENDING_SECONDS then
		sentAt = nil
		return false
	end
	return true
end

function PadPanel.isLeaving(): boolean
	return PadPanel.bannerLineFor(loading, left, pendingPick()) ~= ""
end

-- WHAT IS ACTUALLY ON THE BANNER: its title, its one line and how full its bar is. The read seam a
-- spec and a console probe use instead of guessing -- `Build.padLabel`'s own rule, on the screen.
function PadPanel.leavingText(): (string, string, number)
	local line = if bannerLine then (bannerLine :: TextLabel).Text else ""
	local fill = if bannerFill then (bannerFill :: Frame).Size.X.Scale else 0
	return LEAVING.TITLE, line, fill
end

function PadPanel.leavingFrame(): Frame?
	return banner
end

-- ---------------------------------------------------------------- the rectangles, pure and exported

-- HOW TALL THE WHOLE DIALOG IS, for however many sizes the data lists. PURE, so the rectangle is a
-- spec and not a screenshot -- `ShopPanel.panelSize`'s rule, and `Hud.build` sizes the frame with it
-- so ONE number decides both the rows and the box (the Reviewer's task-178 round-1 note: they used to
-- be two, and a sixth row would have been drawn outside the frame in silence).
function PadPanel.heightFor(count: number?): number
	local rows = count or #PADS.SIZES
	local body = if rows <= 0 then 0 else rows * PANEL.ROW_PX + (rows - 1) * PANEL.GAP
	return PANEL.HEADER_PX + body + PANEL.HINT_PX + PAD
end

function PadPanel.widthFor(): number
	return PANEL.WIDTH
end

function PadPanel.zIndex(): number
	return PANEL.Z_INDEX
end

-- THE BANNER'S RECTANGLE: **full width** less a margin each side, capped so a 2560 px desktop gets a
-- banner and not a letterbox. A SCALE and not a viewport read, so nothing re-measures on a resize --
-- which is the one thing `ShopPanel.panelSize` has to do and this does not.
function PadPanel.leavingSize(): UDim2
	return UDim2.new(1, -2 * LEAVING.MARGIN_PX, 0, LEAVING.HEIGHT_PX)
end

function PadPanel.leavingPosition(): UDim2
	return UDim2.fromScale(0.5, LEAVING.Y_SCALE)
end

function PadPanel.leavingZIndex(): number
	return LEAVING.Z_INDEX
end

function PadPanel.leavingMaxWidth(): number
	return LEAVING.MAX_WIDTH
end

-- ---------------------------------------------------------------- the pieces, built once

-- ONE LABEL. The shop's own helper, written out again here rather than exported from it, because
-- what crosses between the two modules is the STYLE (the palette, the faces, the spacing rule) and
-- not a drawing library: `ShopPanel.label` writes that panel's own Z bands and parent assumptions.
local function label(parent: Instance, name: string, face: Font, size: number, colour: Color3, lift: number): TextLabel
	local made = Instance.new("TextLabel")
	made.Name = name
	made.BackgroundTransparency = 1
	made.FontFace = face
	made.TextSize = size
	made.TextColor3 = colour
	made.TextXAlignment = Enum.TextXAlignment.Left
	made.TextYAlignment = Enum.TextYAlignment.Top
	-- EVERY CHILD SITS ABOVE ITS PANEL'S OWN ZINDEX, and task 124's measured defect is why: with the
	-- panel opaque and its labels at the default 1, the whole report came out as an EMPTY BLACK
	-- RECTANGLE -- the text was being drawn BEHIND its own background.
	made.ZIndex = PANEL.Z_INDEX + lift
	-- NO `UIStroke` ON ANY TEXT IN THIS PANEL (spec 8, and `ShopPanel`'s own note). The black outline
	-- the rest of this Hud wears is there to hold text over a sunlit forest; the panel is opaque, and
	-- removing it is half of why the new one looks cleaner.
	made.Parent = parent
	return made
end

local function corner(parent: Instance, radius: number)
	local made = Instance.new("UICorner")
	made.CornerRadius = UDim.new(0, radius)
	made.Parent = parent
end

local function stroke(parent: Instance, colour: Color3, transparency: number)
	local made = Instance.new("UIStroke")
	made.Thickness = 1
	made.Color = colour
	made.Transparency = transparency
	made.Parent = parent
	return made
end

-- THE ONE BRASS HAIRLINE that separates a header from a body (spec 8.2: *"Never two rules in a row,
-- never a box drawn with four of them"*), faded at both ends exactly as the shop's is.
local function hairline(parent: Instance, y: number, lift: number): Frame
	local line = Instance.new("Frame")
	line.Name = "Hairline"
	line.BorderSizePixel = 0
	line.BackgroundColor3 = LOOK.BRASS
	line.Position = UDim2.fromOffset(0, y)
	line.Size = UDim2.new(1, 0, 0, HAIRLINE_PX)
	line.ZIndex = PANEL.Z_INDEX + lift
	line.Parent = parent
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.12, 0.58),
		NumberSequenceKeypoint.new(0.88, 0.58),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = line
	return line
end

local function build(frame: Frame)
	panel = frame
	corner(frame, CORNER_PANEL)
	stroke(frame, LOOK.BRASS, 0.74)

	-- THE HEADER (spec 3.2): the eyebrow, the title, and the hairline under them. The eyebrow carries
	-- WHICH TRUCK, which until this task was only on the billboard outside -- and the pad index is
	-- already on this client, so it costs no wire.
	eyebrow = label(frame, "Eyebrow", FONT.SANS_SEMI, EYEBROW_SIZE, LOOK.BRASS, 1);
	(eyebrow :: TextLabel).Position = UDim2.fromOffset(PAD, 13);
	(eyebrow :: TextLabel).Size = UDim2.new(1, -2 * PAD, 0, EYEBROW_SIZE + 3);
	(eyebrow :: TextLabel).Text = spaced(string.format(PANEL.EYEBROW, 1))

	title = label(frame, "Title", FONT.OSWALD_SB, TITLE_SIZE, LOOK.PAPER, 1);
	(title :: TextLabel).Position = UDim2.fromOffset(PAD, 27);
	(title :: TextLabel).Size = UDim2.new(1, -2 * PAD, 0, TITLE_SIZE + 6);
	(title :: TextLabel).Text = PANEL.TITLE

	hairline(frame, PANEL.HEADER_PX - HAIRLINE_PX, 1)

	table.clear(buttons)
	table.clear(notes)
	for index, row in ipairs(PADS.SIZES) do
		local button = Instance.new("TextButton")
		button.Name = string.format("Size%d", row.size)
		button.AutoButtonColor = false
		button.BackgroundColor3 = PadPanel.LOOK.BUTTON_COLOR
		button.BorderSizePixel = 0
		-- THE BUTTON CARRIES NO TEXT OF ITS OWN: the number and the line are child labels, which is
		-- the shop's big-button arrangement (its spec section 4) and the only way to set two faces at
		-- two sizes in one control.
		button.Text = ""
		button.Position = UDim2.fromOffset(PAD, PANEL.HEADER_PX + (index - 1) * (PANEL.ROW_PX + PANEL.GAP))
		-- AN OFFSET AND NOT A SCALE, so `pad_panel.spec`'s *"none of them is wider than the panel"*
		-- stays a real comparison: against a scale it would read -28 against 320 and pass by accident.
		button.Size = UDim2.fromOffset(PANEL.WIDTH - 2 * PAD, PANEL.BUTTON_PX)
		button.ZIndex = PANEL.Z_INDEX + 2
		button.ClipsDescendants = true
		corner(button, CORNER_ROW)
		stroke(button, PadPanel.LOOK.RIM_COLOR, 0.15)

		-- ROW 1 IS THE DEFAULT AND WEARS THE ONE ORANGE THING (spec 5, the selected treatment): a
		-- 4 px bar down its left edge, the row's own `UICorner` rounding its ends with it. What it
		-- marks is `Pads.defaultSize` -- the size a pick nobody makes falls back to -- so it is a
		-- fact about the game and not a recommendation, and no other row carries an orange anything.
		if index == 1 then
			local mark = Instance.new("Frame")
			mark.Name = "Default"
			mark.BorderSizePixel = 0
			mark.BackgroundColor3 = LOOK.BLAZE
			mark.Position = UDim2.fromScale(0, 0)
			mark.Size = UDim2.new(0, SELECTED_BAR_PX, 1, 0)
			mark.ZIndex = PANEL.Z_INDEX + 3
			mark.Parent = button
			local bar = Instance.new("UIGradient")
			bar.Color = ColorSequence.new(LOOK.BLAZE_HI, LOOK.BLAZE_LO)
			bar.Rotation = 90
			bar.Parent = mark
		end

		local name = label(button, "Label", FONT.OSWALD_MD, LABEL_SIZE, LOOK.PAPER, 3)
		name.Position = UDim2.fromOffset(PAD, 8)
		name.Size = UDim2.new(1, -2 * PAD, 0, LABEL_SIZE + 4)
		-- THE LABEL IS THE DATA'S OWN, not a format applied here: Karen wrote `1 / 1` and `4 / 4`
		-- herself, which is what makes the words hers to retune.
		name.Text = row.label

		local note = label(button, "Note", FONT.SANS_REG, NOTE_SIZE, LOOK.MUTED, 3)
		note.Position = UDim2.fromOffset(PAD, 8 + LABEL_SIZE + 5)
		note.Size = UDim2.new(1, -2 * PAD, 0, NOTE_SIZE + 4)
		note.Text = row.note or ""
		table.insert(notes, note)

		-- THE 0.12 s COLOUR TWEEN ON HOVER AND PRESS, and it is the only thing in this panel that
		-- moves (spec 8.9). `GuiObject.MouseEnter` / `MouseLeave` fire for a mouse and never for a
		-- finger, which is right: a finger has no hover.
		button.MouseEnter:Connect(function()
			if sent == nil then
				button.BackgroundColor3 = PadPanel.LOOK.ROW_HOVER_COLOR
			end
		end)
		button.MouseLeave:Connect(function()
			button.BackgroundColor3 = PadPanel.LOOK.BUTTON_COLOR
		end)
		-- THE SIZE IS CLOSED OVER AND THE PAD IS READ AT PRESS TIME, so a dialog that has re-opened
		-- for a different pad cannot send a pick for the one it used to show (`ShopPanel`'s
		-- `buy.Activated` rule).
		button.Activated:Connect(function()
			PadPanel.press(row.size)
		end)
		button.Parent = frame
		table.insert(buttons, button)
	end

	-- THE ONE MESSAGE LINE (spec 8.8), and this dialog's caveat is its own way out: there is no close
	-- button on purpose, so the other exit has to be written down somewhere.
	local hint = label(frame, "Hint", FONT.SANS_BOLD, HINT_SIZE, LOOK.FAINT, 1)
	hint.Position = UDim2.fromOffset(PAD, PadPanel.heightFor() - PANEL.HINT_PX)
	hint.Size = UDim2.new(1, -2 * PAD, 0, PANEL.HINT_PX)
	hint.Text = spaced(PANEL.HINT)
	hint.TextTruncate = Enum.TextTruncate.AtEnd
end

-- THE LOADING BANNER. KAREN: *"we need clear message that game is loading once clicked 1/1 or other
-- now is delay"*.
local function buildBanner(frame: Frame)
	banner = frame
	corner(frame, CORNER_PANEL)
	stroke(frame, LOOK.BRASS, 0.74)
	-- THE CAP, so *"full width"* is a banner on a desktop and the whole screen on a phone.
	local cap = Instance.new("UISizeConstraint")
	cap.MaxSize = Vector2.new(LEAVING.MAX_WIDTH, math.huge)
	cap.Parent = frame

	bannerEyebrow = label(frame, "Eyebrow", FONT.SANS_SEMI, EYEBROW_SIZE, LOOK.BRASS, 1);
	(bannerEyebrow :: TextLabel).Position = UDim2.fromOffset(PAD + 4, 14);
	(bannerEyebrow :: TextLabel).Size = UDim2.new(1, -2 * (PAD + 4), 0, EYEBROW_SIZE + 3);
	(bannerEyebrow :: TextLabel).TextXAlignment = Enum.TextXAlignment.Center;
	-- THE EYEBROW CARRIES NO NUMBER, and `LEAVING.EYEBROW`'s own comment says why: measured in the
	-- live Forest Test, the first banner read TRUCK 1 over a player standing on pad 2, because this
	-- client has no pad index once the dialog has shut. Written ONCE here and never again.
	(bannerEyebrow :: TextLabel).Text = spaced(LEAVING.EYEBROW)

	local head = label(frame, "Title", FONT.OSWALD_SB, TITLE_SIZE, LOOK.PAPER, 1)
	head.Position = UDim2.fromOffset(PAD + 4, 28)
	head.Size = UDim2.new(1, -2 * (PAD + 4), 0, TITLE_SIZE + 6)
	head.TextXAlignment = Enum.TextXAlignment.Center
	head.Text = LEAVING.TITLE

	bannerLine = label(frame, "Line", FONT.SANS_SEMI, LEAVING_LINE_SIZE, LOOK.COIN_TEXT, 1);
	(bannerLine :: TextLabel).Position = UDim2.fromOffset(PAD + 4, 28 + TITLE_SIZE + 10);
	(bannerLine :: TextLabel).Size = UDim2.new(1, -2 * (PAD + 4), 0, LEAVING_LINE_SIZE + 4);
	(bannerLine :: TextLabel).TextXAlignment = Enum.TextXAlignment.Center;
	(bannerLine :: TextLabel).Text = ""

	-- THE BAR. Track one step darker than the panel (spec 8.1), fill in blaze orange -- the one
	-- orange thing on this screen, and the only thing in this Hud that is allowed to move because it
	-- is a VALUE and not decoration.
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BorderSizePixel = 0
	track.BackgroundColor3 = LOOK.ROW
	track.AnchorPoint = Vector2.new(0.5, 1)
	track.Position = UDim2.new(0.5, 0, 1, -(PAD + 2))
	track.Size = UDim2.new(1, -2 * (PAD + 6), 0, LEAVING.BAR_PX)
	track.ZIndex = PANEL.Z_INDEX + 1
	track.ClipsDescendants = true
	track.Parent = frame
	corner(track, math.floor(LEAVING.BAR_PX / 2))
	bannerTrack = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = LOOK.BLAZE
	fill.Position = UDim2.fromScale(0, 0)
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = PANEL.Z_INDEX + 2
	fill.Parent = track
	local sweep = Instance.new("UIGradient")
	sweep.Color = ColorSequence.new(LOOK.BLAZE_LO, LOOK.BLAZE_HI)
	sweep.Parent = fill
	bannerFill = fill
end

-- ---------------------------------------------------------------- the two things it is told

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
	-- ...AND SO IS THE BANNER THAT CLICK PUT UP (task 209), but ONLY for a different pad ASKING. The
	-- distinction is load-bearing: a pick the server ACCEPTS stops that pad asking (`DHPadFirst`
	-- goes), so `ask` falls to nil one scan after every successful click -- clearing on nil would
	-- take the banner down again in the very gap it exists to fill.
	if ask ~= nil then
		sentAt = nil
	end
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

-- WHICH STATE THE PAD TAKING THIS PLAYER IS IN, and how many seconds are left. TOLD, both of them,
-- out of the one evaluation the Hud already runs: the state is `DHPadMine` on this player and the
-- seconds are the `DHLobbyLeaveAt` the Hud already converts for the objective line, so this module
-- reads no attribute and holds no clock.
--
-- THE SECONDS ARE NOT EDGE-TRIGGERED AND CANNOT BE: they change every frame, which is the point of
-- them. The STATE is, and the bar is written only when its scale actually moves by a pixel's worth --
-- `stats.barWrites` is what makes that claim checkable rather than a comment.
function PadPanel.setLeaving(state: string?, secondsLeft: number?, now: number?)
	-- THE CLOCK IS TOLD, NOT TAKEN (task 209), for the reason the seconds already are: this module
	-- holds no clock, the Hud's one evaluation has one, and a spec can hand it any number it likes.
	if type(now) == "number" then
		shownAt = now :: number
	end
	if type(state) ~= "string" or not LobbyData.padLoading(state) then
		state = nil
	end
	-- THE SERVER HAS SPOKEN, SO THIS CLIENT'S GUESS IS OVER. One line, and it is the whole of what
	-- makes the optimistic banner safe: from here on the words are the world's.
	if state ~= nil then
		sentAt = nil
	end
	local was = loading
	loading = state
	left = if type(secondsLeft) == "number" then secondsLeft else nil
	if loading ~= nil and was == nil then
		stats.leavingOpens += 1
	elseif loading == nil and was ~= nil then
		stats.leavingCloses += 1
	end
	PadPanel.renderLeaving()
end

function PadPanel.render()
	stats.renders += 1
	local frame = panel
	if frame == nil then
		return
	end
	frame.Visible = ask ~= nil
	if eyebrow ~= nil and ask ~= nil then
		local want = spaced(string.format(PANEL.EYEBROW, ask :: number))
		if (eyebrow :: TextLabel).Text ~= want then
			(eyebrow :: TextLabel).Text = want
		end
	end
	for _, button in ipairs(buttons) do
		-- ONCE A PICK IS IN FLIGHT THE WHOLE ROW DIMS, so a tap that has been sent looks like a tap
		-- that happened and the dialog stops inviting a second one. It is COSMETIC: the server
		-- decides, and `sent` only ever stops THIS client sending the same number twice.
		local dim = sent ~= nil
		button.BackgroundColor3 = PadPanel.LOOK.BUTTON_COLOR
		for _, child in ipairs(button:GetChildren()) do
			if child:IsA("TextLabel") then
				(child :: TextLabel).TextTransparency = if dim then 0.45 else 0
			end
		end
	end
end

function PadPanel.renderLeaving()
	local frame = banner
	if frame == nil then
		return
	end
	local line = PadPanel.bannerLineFor(loading, left, pendingPick())
	-- WRITTEN ONLY WHEN IT DIFFERS. This one is called EVERY FRAME -- the seconds change every frame,
	-- which is the point of them -- so it is the one renderer in this module that cannot be
	-- edge-triggered from outside, and the writes are edge-triggered INSIDE instead: the `Visible`,
	-- the line and the eyebrow each compare first, and the bar has its own threshold below. That is
	-- `Lobby.setRespawn`'s discipline on the server's side of the same system.
	if frame.Visible ~= (line ~= "") then
		frame.Visible = line ~= ""
	end
	if line == "" then
		return
	end
	if bannerLine ~= nil and (bannerLine :: TextLabel).Text ~= line then
		(bannerLine :: TextLabel).Text = line
	end
	local fraction = PadPanel.barFraction(loading, left)
	if bannerTrack ~= nil then
		(bannerTrack :: Frame).Visible = fraction ~= nil
	end
	if bannerFill ~= nil and fraction ~= nil then
		local was = (bannerFill :: Frame).Size.X.Scale
		if math.abs(was - (fraction :: number)) >= 0.004 then
			(bannerFill :: Frame).Size = UDim2.fromScale(fraction :: number, 1)
			stats.barWrites += 1
		end
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
	-- THE BANNER GOES UP HERE, ON THE CLICK, BEFORE THE SERVER HAS BEEN ASKED ANYTHING (task 209).
	-- Karen: *"once I click I need imeadiatly show loading (Leaving dfor hunting)"*; it was 3.65 s,
	-- measured through a real left click on her own path. `shownAt` is the Hud's last clock rather
	-- than a new reading, so the window below is measured in the same seconds the Hud counts in and
	-- is at most one frame stale.
	sentAt = shownAt
	stats.optimistic += 1
	PadPanel.renderLeaving()
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
	-- THE BANNER'S FRAME IS OPTIONAL, for the reason every collaborator in this Hud is: a spec that
	-- takes the panel over hands it one frame (`pad_panel.spec`'s own case), and a module that threw
	-- without the second would make the dialog untestable to add a banner to it.
	if bag.leaving ~= nil then
		buildBanner(bag.leaving);
		(bag.leaving :: Frame).Visible = false
	end
	PadPanel.render()
	PadPanel.renderLeaving()
end

-- THE TEARDOWN A CLIENT SPEC NEEDS: nothing on screen, nothing held, and the two doors handed back.
--
-- IT EMPTIES THE FRAMES IT WAS GIVEN, and the Reviewer's round-1 note is why: `start` calls `build`
-- unconditionally, so a `stop` that left the title and the four buttons standing meant a re-start on
-- the same frame ended with DOUBLED children -- a spec that put the live dialog back leaving the
-- screen worse than it found it. `UICorner`, `UIStroke` and `UIGradient` are not `GuiObject`s, so
-- this clears every child and not only the visible ones (task 197: the restyle added five of them per
-- frame, and a doubled `UIStroke` is a doubled stroke).
local function empty(frame: Frame?)
	if frame == nil then
		return
	end
	frame.Visible = false
	for _, child in ipairs((frame :: Frame):GetChildren()) do
		child:Destroy()
	end
end

function PadPanel.stop()
	if ask ~= nil then
		PadPanel.setAsk(nil)
	end
	started = false
	ask = nil
	sent = nil
	loading = nil
	left = nil
	table.clear(buttons)
	table.clear(notes)
	empty(panel)
	empty(banner)
	panel = nil
	banner = nil
	eyebrow = nil
	title = nil
	bannerEyebrow = nil
	bannerLine = nil
	bannerTrack = nil
	bannerFill = nil
	remotes = nil
	Cursor = nil
	WeaponInput = nil
end

return PadPanel
