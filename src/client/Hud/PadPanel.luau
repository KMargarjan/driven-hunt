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
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyData = require(ReplicatedStorage:WaitForChild("Lobby"))
-- THE HOUSE STYLE, FROM THE ONE MODULE THAT DEFINES IT. A read of a frozen palette and five `Font`
-- values; `ShopPanel` requires nothing of this module back, so there is no cycle.
local ShopPanel = require(script.Parent.ShopPanel)

local PadPanel = {}

local PADS = LobbyData.CONFIG.PADS
local PANEL = PADS.PANEL
local LEAVING = PADS.LEAVING

-- THE PAD DIALOG'S OWN ROLE BLOCK (task 229): its words and the ten pixel rows only this dialog
-- has. The CONTROL's own geometry is the house style's and lives in `Shop.CONFIG.PANEL.ROLE_SWITCH`,
-- read here as `SWITCH` -- one control, two surfaces, one set of numbers.
local ROLE = PANEL.ROLE
local SWITCH = ShopPanel.ROLE_SWITCH

-- ---------------- THE KEY ON THE ROLE SWITCH (task 244)
--
-- KAREN, 2026-10-22: *"I still can't select before game who I want to be"*. The CAUSE was a dead
-- wire (see `PadPanel.start`), and the key is the belt to that fix's braces: `Hud.LicenceCard`'s
-- own reasoning, measured rather than assumed -- *"in first person `Camera.Cursor` locks the mouse
-- to the centre of the screen, so a `GuiButton` receives no click"*. This dialog frees the cursor
-- while it is open (`Cursor.requestFree("padsize")`), so the halves ARE clickable here; a key
-- costs one binding and answers the whole class of reasons a press can go missing.
--
-- `T` FOR TEAM, AND IT IS FREE: the sixteen `Enum.KeyCode`s bound anywhere in `src/` are
-- Backspace, B, E, M, R, Tab, X, Return, the four arrows and four gamepad buttons.
--
-- ONE KEY AND NOT TWO, because the control has exactly two states and a toggle is the only shape
-- that needs no second chip. The chip says so in Karen's own words (`ROLE.KEY_HINT`).
local SWITCH_KEY = Enum.KeyCode.T
local SWITCH_ACTION = "DrivenHuntPadRoleSwitch"

-- ---------------- THE NEXT DRIVE'S CARD (task 246)
--
-- KAREN, 2026-10-23: *"we need continues game so after drive new drive imidiatly after same amount
-- seconds and who has licesne can select who he can be next round if dont then oposit previuos
-- round"*.
--
-- ITS WORDS AND ITS PIXELS, from the one table both sides read. This card is the THIRD surface this
-- module owns, and it is this module's rather than a new one for `buildBanner`'s stated reason: it
-- is the same question continued (*"which drive are you going on"*), it is driven by the same
-- server-written attributes, it needs the same mouse and trigger doors released, and it already has
-- the role switch -- a second module would be a second reader of the same facts.
local NEXT = PADS.NEXT

-- `Y` FOR THE WAY OUT, and the choice is `T`'s own argument one key along: `T` toggles the role on
-- this same card, so the two next-drive controls are NEIGHBOURS on the keyboard rather than a
-- memory test. It is free -- the keys bound anywhere in `src/` are Backspace, B, E, M, R, T, Tab, X,
-- Return, the four arrows and four gamepad buttons -- and it is bound ONLY while this card is up
-- (`bindSitKey`), so `Y` belongs to the player again the moment the drive takes him.
local SIT_KEY = Enum.KeyCode.Y
local SIT_ACTION = "DrivenHuntNextSitOut"

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
-- ---------------- THE ROLE SWITCH (task 229)
--
-- `wish` IS THE SERVER'S WORD AND THIS MODULE'S ONLY OPINION ABOUT IT IS WHICH HALF IS LIT. It is
-- TOLD by the Hud's one evaluation off the `DHRoleWish` attribute (`setRoleWish`), exactly as
-- `loading` is told off `DHPadMine`; nil means he does not own `ALWAYS HUNTER` and the block is not
-- drawn at all.
local wish: string? = nil
-- WHAT SIDE THE DRIVE HAS GIVEN HIM, told with it: the caption's own fact, and it is `Player.Team`
-- read ONCE a frame by the Hud rather than a second read here.
local team: string? = nil
local screenHeight: number? = nil
local switchBlock: Frame? = nil
local switchEyebrow: TextLabel? = nil
-- THE KEY CHIP ON THE EYEBROW ROW (task 244), right-aligned beside `NEXT DRIVE`. It shares the row
-- rather than taking one, so `ROLE.BLOCK_PX` does not move and `heightFor`'s arithmetic is
-- untouched -- which is what `pad_panel.spec`'s `heightFor(n, true) - heightFor(n, false)` asserts.
local switchKeyChip: TextLabel? = nil
-- IS THE KEY BOUND RIGHT NOW? One boolean, so `bindSwitchKey` is idempotent and a double open
-- cannot leave a second action behind (`LicenceCard.bindBuyKey`'s shape).
local switchKeyBound = false
local switchCaption: TextLabel? = nil
local switchRule: Frame? = nil
local roleSwitch: any = nil
local hint: TextLabel? = nil

-- ---------------- THE NEXT DRIVE'S CARD (task 246): four values, one writer
--
-- `nextLeft` IS THE SECONDS AND nil IS "THERE IS NO COUNTDOWN", which is the whole visibility rule
-- of this card -- `Lobby.secondsLeft`'s own contract (*"nil in, nil out: 'there is no countdown' is
-- not 'zero seconds left'"*), carried all the way to the screen. It is TOLD by the Hud's one
-- evaluation off `DHNextDriveAt`, exactly as `loading` is told off `DHPadMine`.
--
-- `nextOut` IS THE SERVER'S WORD TOO (`DHNextDriveOut`) and this module holds no opinion about it:
-- the button says what the server said and never what this client asked for, which is the arrangement
-- `sendRoleWish` already argues for in capitals.
local nextLeft: number? = nil
local nextOut = false
local nextCard: Frame? = nil
local nextEyebrow: TextLabel? = nil
local nextTitle: TextLabel? = nil
local nextCount: TextLabel? = nil
local nextButton: TextButton? = nil
local nextButtonWord: TextLabel? = nil
local nextKeyChip: TextLabel? = nil
local nextNote: TextLabel? = nil
local nextHint: TextLabel? = nil
local nextRoleBlock: Frame? = nil
local nextRoleEyebrow: TextLabel? = nil
local nextRoleCaption: TextLabel? = nil
-- THE SECOND ROLE SWITCH, BUILT BY THE SAME BUILDER AS THE FIRST (`ShopPanel.buildRoleSwitch`).
-- The control is already drawn on two surfaces -- this dialog and the shop's row -- so a third is
-- the established pattern and not a new one, and `ShopPanel.paintRoleSwitch` stays the one painter,
-- which is what stops the three surfaces disagreeing about what "selected" looks like.
local nextRoleSwitch: any = nil
local sitKeyBound = false

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
	-- THE ROLE SWITCH (task 229). `roleSent` is a message that left; `roleBlocked` is a press this
	-- module refused to send (an unknown word, or a control that is not usable); `relayouts` is how
	-- many times every rectangle in this dialog was rewritten, which has to stay ONE PER CHANGE and
	-- not one per frame -- `pad_panel.spec` asserts exactly that.
	roleSent = 0,
	roleBlocked = 0,
	relayouts = 0,
	-- THE NEXT DRIVE'S CARD (task 246), on `roleSent`/`roleBlocked`'s own split: `nextOpens` and
	-- `nextCloses` are the card itself, `nextSent` a message that left, `nextBlocked` a press this
	-- module refused to send (no countdown is up, so there is no party to be in).
	nextOpens = 0,
	nextCloses = 0,
	nextSent = 0,
	nextBlocked = 0,
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
function PadPanel.heightFor(count: number?, withSwitch: boolean?): number
	local rows = count or #PADS.SIZES
	local body = if rows <= 0 then 0 else rows * PANEL.ROW_PX + (rows - 1) * PANEL.GAP
	-- `withSwitch` nil or false IS TODAY'S NUMBER, so every existing caller of this function is
	-- unchanged by construction (task 229).
	local block = if withSwitch == true then ROLE.BLOCK_PX else 0
	return PANEL.HEADER_PX + block + body + PANEL.HINT_PX + PAD
end

-- ---------------------------------------------------------------- the role switch, pure (task 229)
--
-- KAREN, 2026-10-21: *"we also need to have posibility to choose once you have a card always hunter
-- maybe sometimes I want to be a beater we need to find a way to do that"*.

-- IS THERE ROOM FOR THE BLOCK ON THIS SCREEN? PURE.
--
-- The dialog is 487 tall with the block, and at 400 px -- *"a landscape phone, which is how phones
-- play"* (`docs/design/camera.md`, task 220) -- it does not fit: today's 368 already leaves only
-- 16 px of margin there. So the pad surface DROPS the block rather than drawing it off the bottom,
-- and the feature is still reachable because the SHOP's panel scales
-- (`ShopPanel.layoutFor`'s own `clamp(floor(screenH * 0.8), 300, 640)`) -- which is why there are
-- two surfaces at all.
--
-- A nil HEIGHT ANSWERS false: the small guess, which is `ShopPanel.screenSize`'s own stated rule
-- (*"a layout that guessed big would overflow a phone"*).
function PadPanel.switchFitsIn(height: number?): boolean
	if type(height) ~= "number" then
		return false
	end
	return (height :: number) >= PadPanel.heightFor(nil, true) + 2 * LEAVING.MARGIN_PX
end

-- WHICH HALF IS LIT, or nil for "there is no block at all". PURE.
function PadPanel.roleSelected(next_: string?): string?
	if next_ == LobbyData.ROLE_WISH.BEATER then
		return LobbyData.ROLE_WISH.BEATER
	end
	if next_ == LobbyData.ROLE_WISH.HUNTER then
		return LobbyData.ROLE_WISH.HUNTER
	end
	return nil
end

-- WHY THE SWITCH CANNOT BE USED, or "" when it can. PURE, and it is the ONE rule: THREE rows since
-- task 242 (`NOTE_NONE` went with the party-of-one refusal), no string literal in this module, and
-- the words come out of `PANEL.ROLE` so they are Karen's to rewrite.
--
--   * the drive has given him a side  -> he is in it; the wish is spent and the control is a receipt
--   * a size has been pressed        -> `ASKED FOR ALREADY`, WHATEVER THE SIZE (task 242). A party
--     of ONE used to get its own row, `NO BEATERS THIS DRIVE`, because `Roster.assign` honoured
--     nobody at one player; Karen held `ALWAYS HUNTER`, stood on the pad alone, asked to beat and
--     was dealt a stand, and that rule is gone -- a solo wisher is now dealt the beaters' side with
--     bot hunters on the stands. The row went with it
--     (`backups/2026-10-22_task-242_no-beaters-this-drive.md`, rule 7), because a caption that is no
--     longer true is worse than no caption. The block is DISABLED and not hidden:
--     hiding it would make the dialog jump 119 px under the player's thumb while the truck is
--     loading, *"which is the one thing a dialog must never do"*.
function PadPanel.roleCaptionFor(next_: string?, side: string?, size: number?): string
	local words = PANEL.ROLE
	if PadPanel.roleSelected(next_) == nil then
		return ""
	end
	-- ONE CONDITION AND NOT TWO (review round 1, note): a size pressed and a side already dealt are
	-- different FACTS, but since task 242 they are the same SENTENCE, and writing it twice invites
	-- the two copies to drift.
	if size ~= nil or side ~= nil then
		return words.NOTE_SENT
	end
	return if next_ == LobbyData.ROLE_WISH.BEATER then words.NOTE_BEATER else words.NOTE_HUNTER
end

-- MAY EITHER HALF BE PRESSED? PURE. It is false in exactly the two states the caption explains
-- above, so the dimming and the words can never disagree.
function PadPanel.roleUsable(next_: string?, side: string?, size: number?): boolean
	return PadPanel.roleSelected(next_) ~= nil and size == nil and side == nil
end

export type Layout = {
	height: number,
	switchShown: boolean,
	switchY: number,
	trackY: number,
	trackWidth: number,
	halfWidth: number,
	captionY: number,
	ruleY: number,
	rowY: { number },
	hintY: number,
}

-- EVERY RECTANGLE IN THIS DIALOG, FROM THE DATA PLUS TWO FACTS. PURE, which is
-- `ShopPanel.layoutFor`'s own rule and task 165's lesson: *"asserted ARITHMETICALLY rather than by a
-- screenshot"*.
--
-- IT EXISTS BECAUSE OF THE ONE REAL COST OF THIS TASK, and that cost is named rather than hidden:
-- the four size rows' Y and the hint's Y used to be written ONCE in `build`, so a block inserted
-- under the header would have left all five where they were. `relayout` is now the one writer of
-- every rectangle in this dialog and this function is where the numbers come from.
function PadPanel.layoutFor(count: number?, next_: string?, height: number?): Layout
	local rows = count or #PADS.SIZES
	local shown = PadPanel.roleSelected(next_) ~= nil and PadPanel.switchFitsIn(height)
	local block = if shown then ROLE.BLOCK_PX else 0
	local switchY = PANEL.HEADER_PX + ROLE.LEAD_PX
	local trackY = switchY + ROLE.EYEBROW_PX + ROLE.GAP_PX
	local captionY = trackY + ROLE.TRACK_PX + ROLE.NOTE_GAP
	local trackWidth = PANEL.WIDTH - 2 * PAD
	local rowTop = PANEL.HEADER_PX + block
	local rowY = {}
	for index = 1, rows do
		table.insert(rowY, rowTop + (index - 1) * (PANEL.ROW_PX + PANEL.GAP))
	end
	return {
		height = PadPanel.heightFor(rows, shown),
		switchShown = shown,
		switchY = switchY,
		trackY = trackY,
		trackWidth = trackWidth,
		-- `(track - 2*PAD - GAP) / 2`: the formula, not the Designer's drawing, which forgot the
		-- 3 px between the halves (see `Shop.CONFIG.PANEL.ROLE_SWITCH`).
		halfWidth = (trackWidth - 2 * SWITCH.TRACK_PAD - SWITCH.TRACK_GAP) / 2,
		captionY = captionY,
		ruleY = captionY + ROLE.NOTE_PX + ROLE.RULE_GAP,
		rowY = rowY,
		hintY = PadPanel.heightFor(rows, shown) - PANEL.HINT_PX,
	}
end

-- WHERE THE DIALOG SITS, AND ITS BOTTOM EDGE IS INVARIANT. PURE, and this is a correction made in
-- advance rather than a preference (`docs/design/role-switch.md` section 14.1).
--
-- `LEAVING.Y_SCALE`'s own comment carries the band task 209 round 2 measured off a 368-tall CENTRED
-- dialog: `0.5 + 240/H <= Y_SCALE <= 1 - 56/H`, which is [0.8334, 0.9222] at 720 and holds 0.88.
-- With the block the dialog is 487, so a centred one's lower bound becomes `0.5 + 299.5/H` = 0.916
-- at 720 -- ABOVE 0.88 -- and the dialog's bottom would land at 603.5 with the banner's top at
-- 577.6: **26 px of the dialog's hint band under the banner**, which is the exact defect, in the
-- exact place, that round 2 was spent on. (The two ARE up together: since task 209
-- `PadPanel.press` raises the banner optimistically while the dialog is still open.)
--
-- SO THE BLOCK GROWS UPWARD. `AnchorPoint` is the bottom edge and the position is fixed off TODAY'S
-- height, so the whole of the 209 band arithmetic holds unchanged and `Y_SCALE` is not touched.
function PadPanel.anchorPoint(): Vector2
	return Vector2.new(0.5, 1)
end

function PadPanel.positionFor(): UDim2
	return UDim2.new(0.5, 0, 0.5, PadPanel.heightFor() / 2)
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

	-- THE ROLE BLOCK (task 229), BUILT ONCE AND PLACED BY `relayout`, between the header's hairline
	-- and the four size rows -- *"because the role is a fact about the drive you read BEFORE you
	-- choose a party size, and because anything placed after four 60 px buttons is placed below the
	-- thing the player came to press"* (the Designer's spec section 3.6).
	--
	-- IT IS HIDDEN UNTIL THE SERVER SAYS HE OWNS `ALWAYS HUNTER`. A man who owns nothing never sees
	-- it: absent, not greyed and not locked, because *"a control for a thing you do not have is an
	-- advertisement, and this shop already has a shop for that"*.
	local block = Instance.new("Frame")
	block.Name = "RoleBlock"
	block.BackgroundTransparency = 1
	block.BorderSizePixel = 0
	block.ZIndex = PANEL.Z_INDEX + 2
	block.Visible = false
	block.Parent = frame
	switchBlock = block

	switchEyebrow = label(block, "RoleEyebrow", FONT.SANS_BOLD, EYEBROW_SIZE + 1, LOOK.FAINT, 3);
	(switchEyebrow :: TextLabel).Text = spaced(ROLE.EYEBROW);
	-- THE ROW IS SPLIT, NOT SHARED (task 244, round 1 note): the eyebrow takes everything the key
	-- chip does not, so the two rectangles are disjoint by construction and `TextTruncate` is never
	-- asked to hide a collision.
	(switchEyebrow :: TextLabel).Size = UDim2.new(1, -ROLE.KEY_PX, 0, ROLE.EYEBROW_PX)

	-- THE KEY CHIP, ON THE EYEBROW'S OWN ROW AND RIGHT-ALIGNED (task 244). A key nobody can see is
	-- a key nobody presses -- `LicenceCard`'s `HINT` line said it first, and this is the same line
	-- in the one place this control has room for it. The WORD is Karen's (`ROLE.KEY_HINT`) and the
	-- `%s` is the binding's own `KeyCode.Name`, so the chip and the key cannot drift apart.
	switchKeyChip = label(block, "RoleKey", FONT.SANS_BOLD, EYEBROW_SIZE, LOOK.FAINT, 3);
	(switchKeyChip :: TextLabel).Text = spaced(string.format(ROLE.KEY_HINT, SWITCH_KEY.Name));
	(switchKeyChip :: TextLabel).AnchorPoint = Vector2.new(1, 0);
	(switchKeyChip :: TextLabel).Size = UDim2.fromOffset(ROLE.KEY_PX, ROLE.EYEBROW_PX);
	(switchKeyChip :: TextLabel).TextXAlignment = Enum.TextXAlignment.Right;
	(switchKeyChip :: TextLabel).TextTruncate = Enum.TextTruncate.AtEnd

	-- THE CONTROL ITSELF IS `ShopPanel`'S, built and painted there (task 229): it is drawn on two
	-- surfaces and *"the shop sets the house style"*. What stays here is WHERE it goes, which is
	-- this module's own rectangle to write.
	roleSwitch = ShopPanel.buildRoleSwitch(
		block,
		3,
		ROLE.WORD_SIZE,
		{ [LobbyData.ROLE_WISH.HUNTER] = ROLE.HUNTER, [LobbyData.ROLE_WISH.BEATER] = ROLE.BEATER },
		function(which: string)
			PadPanel.sendRoleWish(which)
		end
	)

	switchCaption = label(block, "RoleCaption", FONT.SANS_BOLD, HINT_SIZE, LOOK.FAINT, 3);
	(switchCaption :: TextLabel).Size = UDim2.new(1, 0, 0, ROLE.NOTE_PX);
	(switchCaption :: TextLabel).TextTruncate = Enum.TextTruncate.AtEnd

	-- THE 1 px RULE under the caption, inset each side, which is what separates the role from the
	-- four sizes. ONE hairline, never a box (spec 8.2).
	local rule = Instance.new("Frame")
	rule.Name = "RoleRule"
	rule.BorderSizePixel = 0
	rule.BackgroundColor3 = LOOK.LINE
	rule.BackgroundTransparency = 0.55
	rule.ZIndex = PANEL.Z_INDEX + 3
	rule.Parent = block
	switchRule = rule

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
		-- NO POSITION HERE ANY MORE (task 229). `PadPanel.relayout` is the one writer of every
		-- rectangle in this dialog, because the role block is inserted ABOVE these rows: a Y written
		-- once at build time would have left all five of them where they were when the block
		-- appeared (`docs/design/role-switch.md` hazard 10).
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
	local line = label(frame, "Hint", FONT.SANS_BOLD, HINT_SIZE, LOOK.FAINT, 1)
	line.Size = UDim2.new(1, -2 * PAD, 0, PANEL.HINT_PX)
	line.Text = spaced(PANEL.HINT)
	line.TextTruncate = Enum.TextTruncate.AtEnd
	hint = line

	-- ...AND EVERY RECTANGLE IS WRITTEN ONCE, HERE, by the one function that writes them all.
	PadPanel.relayout()
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
	-- A NEW PAD IS A NEW QUESTION FOR THE ROLE BLOCK TOO (task 229): `sent` has just been cleared
	-- above, so the switch is usable again and its caption has to say so.
	PadPanel.renderRole()
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
		-- ...AND THE ROLE SWITCH'S KEY, on the same edge and released on the same one (task 244).
		-- It is bound whether or not the block is SHOWN: `toggleRoleWish` answers nil for a man
		-- with no wish and `sendRoleWish` refuses an unusable switch, so the key can never do
		-- something the control would not -- and binding it on the dialog's own edge keeps the two
		-- call sites down to the two this module already has.
		PadPanel.bindSwitchKey(true)
	elseif ask == nil and wasOpen then
		stats.closes += 1
		if Cursor ~= nil then
			Cursor.release("padsize")
		end
		if WeaponInput ~= nil then
			WeaponInput.releaseHold("padsize")
		end
		PadPanel.bindSwitchKey(false)
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

-- ---------------------------------------------------------------- the role switch (task 229)

-- THE ONE WRITER OF EVERY RECTANGLE IN THIS DIALOG, from the pure `layoutFor` --
-- `ShopPanel.relayout`'s arrangement. `build` writes no position at all, so there is exactly one
-- place that can put a row in the wrong place.
function PadPanel.relayout()
	local frame = panel
	if frame == nil then
		return
	end
	stats.relayouts += 1
	local out = PadPanel.layoutFor(#PADS.SIZES, wish, screenHeight)
	-- THE BOTTOM EDGE DOES NOT MOVE (section 14.1 of the design): the anchor is the bottom, the
	-- position is fixed off TODAY'S height, and the block is added at the top. So the whole of task
	-- 209's banner-overlap arithmetic holds and `LEAVING.Y_SCALE` is not touched.
	frame.AnchorPoint = PadPanel.anchorPoint()
	frame.Position = PadPanel.positionFor()
	frame.Size = UDim2.fromOffset(PANEL.WIDTH, out.height)
	if switchBlock ~= nil then
		local block = switchBlock :: Frame
		block.Visible = out.switchShown
		block.Position = UDim2.fromOffset(PAD, out.switchY)
		block.Size = UDim2.fromOffset(PANEL.WIDTH - 2 * PAD, out.ruleY + ROLE.RULE_PX - out.switchY)
	end
	-- EVERY CHILD'S Y IS RELATIVE TO THE BLOCK, so the block is the only thing that moves when the
	-- dialog grows and the four numbers inside it are the Designer's own table, unchanged.
	if switchEyebrow ~= nil then
		(switchEyebrow :: TextLabel).Position = UDim2.fromOffset(0, 0)
	end
	-- THE KEY CHIP SHARES THE EYEBROW'S ROW (task 244): same Y, the right `ROLE.KEY_PX` of it -- so
	-- it adds no row, `ROLE.BLOCK_PX` does not move, and the four numbers below it are untouched.
	-- Anchored at its right edge, so it is the block's right margin whatever the block is wide.
	if switchKeyChip ~= nil then
		(switchKeyChip :: TextLabel).Position = UDim2.fromScale(1, 0)
	end
	if roleSwitch ~= nil then
		-- THE TRACK IS SHOWN WITH ITS BLOCK AND BY THE SAME WRITER (review round 2, finding 1).
		-- `ShopPanel.buildRoleSwitch` builds it hidden -- `buildButton`'s own arrangement -- and
		-- nothing wrote it true, so the two halves were positioned, painted and never rendered: the
		-- eyebrow and the caption appeared around an empty gap.
		roleSwitch.track.Visible = out.switchShown
		roleSwitch.track.Position = UDim2.fromOffset(0, out.trackY - out.switchY)
		roleSwitch.track.Size = UDim2.fromOffset(out.trackWidth, ROLE.TRACK_PX)
	end
	if switchCaption ~= nil then
		(switchCaption :: TextLabel).Position = UDim2.fromOffset(0, out.captionY - out.switchY)
	end
	if switchRule ~= nil then
		local rule = switchRule :: Frame
		rule.Position = UDim2.fromOffset(ROLE.RULE_INSET, out.ruleY - out.switchY)
		rule.Size = UDim2.new(1, -2 * ROLE.RULE_INSET, 0, ROLE.RULE_PX)
	end
	for index, button in ipairs(buttons) do
		button.Position = UDim2.fromOffset(PAD, out.rowY[index] or 0)
	end
	if hint ~= nil then
		(hint :: TextLabel).Position = UDim2.fromOffset(PAD, out.hintY)
	end
end

-- WHICH ROLE THE SERVER SAYS HE HAS ASKED FOR, what side the drive has given him, and how tall the
-- screen is. TOLD, all three, out of the one evaluation the Hud already runs -- `setLeaving`'s and
-- `Rail.setWeapon`'s rule (*"`hasWeapon` is TOLD to this module by the Hud, never read here"*) -- so
-- this module reads no attribute and holds no opinion about who owns what.
--
-- EDGE-TRIGGERED ON ALL THREE, and `relayout` is called only when the RECTANGLE can have changed:
-- the wish appearing or disappearing, or the screen crossing `switchFitsIn`. A `team` that changes
-- repaints and never re-lays-out, because the caption's words do not move anything.
function PadPanel.setRoleWish(next_: string?, side: string?, height: number?)
	if type(next_) ~= "string" or not LobbyData.roleAllowed(next_) then
		next_ = nil
	end
	if type(side) ~= "string" then
		side = nil
	end
	-- A nil HEIGHT IS "NO NEW READING", not "zero": the Hud hands one over every frame, and a spec
	-- that drives the wish alone must not un-set the screen it just described.
	local nextHeight = if type(height) == "number" then height else screenHeight
	if wish == next_ and team == side and screenHeight == nextHeight then
		return
	end
	local wasShown = PadPanel.layoutFor(#PADS.SIZES, wish, screenHeight).switchShown
	wish = next_
	team = side
	screenHeight = nextHeight
	if PadPanel.layoutFor(#PADS.SIZES, wish, screenHeight).switchShown ~= wasShown then
		PadPanel.relayout()
		-- ...AND THE CARD WITH IT (task 246). Its role block is shown on the SAME condition, so the
		-- one edge that moves the dialog's rows moves the card's button too -- one call, not a second
		-- rule, which is what stops the two surfaces drifting apart.
		PadPanel.relayoutNext()
	end
	PadPanel.renderRole()
end

-- THE LIT HALF AND THE CAPTION, painted from the three facts this module was told plus the one it
-- holds (`sent`). `ShopPanel.paintRoleSwitch` is the one painter of the control itself, so the two
-- surfaces cannot disagree about what "selected" looks like.
function PadPanel.renderRole()
	local usable = PadPanel.roleUsable(wish, team, sent)
	local selected = PadPanel.roleSelected(wish)
	local caption = spaced(PadPanel.roleCaptionFor(wish, team, sent))
	if roleSwitch ~= nil then
		ShopPanel.paintRoleSwitch(roleSwitch, selected, usable)
		if switchCaption ~= nil then
			if (switchCaption :: TextLabel).Text ~= caption then
				(switchCaption :: TextLabel).Text = caption
			end
		end
	end
	-- ...AND THE SAME THREE VALUES ON THE NEXT DRIVE'S CARD (task 246). THE SAME PAINTER, THE SAME
	-- ARGUMENTS, COMPUTED ONCE: the two surfaces cannot disagree about which half is lit or about why
	-- it is dimmed, because there is one evaluation of each and one `ShopPanel.paintRoleSwitch`.
	if nextRoleSwitch ~= nil then
		ShopPanel.paintRoleSwitch(nextRoleSwitch, selected, usable)
		if nextRoleCaption ~= nil then
			if (nextRoleCaption :: TextLabel).Text ~= caption then
				(nextRoleCaption :: TextLabel).Text = caption
			end
		end
	end
end

-- THE ONE CLIENT SENDER (design section 4.1). This module is already *"this client's one door onto
-- `ReplicatedStorage.Lobby.Remotes`"*, so the shop panel is handed this function rather than a
-- remote -- which keeps one sender and adds no require edge.
--
-- IT SENDS NOTHING FOR A WORD THAT IS NOT IN `Lobby.ROLE_WISH`, and nothing at all while the control
-- is not usable: the server refuses both anyway (`bad-request`, counted as a forgery), and a client
-- that sent one would be this client telling the server a lie about its own catalogue.
--
-- NO OPTIMISTIC REDRAW, and that is deliberate rather than an omission. Task 209's banner exists
-- because a MEASURED 3.65 s of silence followed a click -- the pad's own `sizing -> filling` round
-- trip through a 10 Hz scan. Here the server writes the attribute INSIDE `Lobby.onRoleRequest`, so
-- the round trip is one network hop; and a half that lit itself would be a client holding an opinion
-- about a value whose whole security is that it does not.
function PadPanel.sendRoleWish(which: string): boolean
	if not LobbyData.roleAllowed(which) or not PadPanel.roleUsable(wish, team, sent) then
		stats.roleBlocked += 1
		return false
	end
	if remotes ~= nil and remotes.RoleRequest ~= nil then
		remotes.RoleRequest:FireServer({ role = which })
		stats.roleSent += 1
		return true
	end
	stats.roleBlocked += 1
	return false
end

-- THE OTHER HALF OF THE SWITCH. PURE, so the key, a spec and a probe all ask the same question and
-- this module keeps no second opinion about what "the other one" means.
--
-- nil IN, nil OUT: a man with no wish has no block on screen and nothing to toggle.
function PadPanel.otherRole(next_: string?): string?
	local lit = PadPanel.roleSelected(next_)
	if lit == nil then
		return nil
	end
	return if lit == LobbyData.ROLE_WISH.BEATER then LobbyData.ROLE_WISH.HUNTER else LobbyData.ROLE_WISH.BEATER
end

-- THE KEY'S ONE ACTION (task 244): ask for the half that is NOT lit. It goes through
-- `sendRoleWish`, which is this client's one sender -- so the key and a press are one code path and
-- every guard is asked once (`Hud.Rail`'s rule: *"`Activated` is still the only thing that RUNS
-- anything"*, said the other way round).
function PadPanel.toggleRoleWish(): boolean
	local other = PadPanel.otherRole(wish)
	if other == nil then
		stats.roleBlocked += 1
		return false
	end
	return PadPanel.sendRoleWish(other)
end

-- THE KEY IS BOUND ONLY WHILE THE DIALOG IS UP, which is `LicenceCard.bindBuyKey`'s arrangement and
-- its stated reason: `T` belongs to the player again the instant he steps off the pad, and a dialog
-- that never opened never took a key at all. Idempotent, so the two call sites cannot stack two
-- actions on one key.
--
-- PUBLIC, and for one reason only: its two callers -- `setAsk` and `stop` -- are written ABOVE it
-- in this file, and a `PadPanel.` call is resolved when it RUNS. A forward-declared local would do
-- the same job and read worse. `switchKeyBound()` below is what a spec asserts.
function PadPanel.bindSwitchKey(on: boolean)
	if on == switchKeyBound then
		return
	end
	switchKeyBound = on
	if on then
		ContextActionService:BindAction(SWITCH_ACTION, function(_name, state)
			if state == Enum.UserInputState.Begin then
				PadPanel.toggleRoleWish()
			end
			-- `Pass`, DELIBERATELY, and it is `LicenceCard`'s rule applied again: this dialog must
			-- not swallow an input. Nothing else binds `T`, so passing costs nothing today and is
			-- the safe answer the day something does.
			return Enum.ContextActionResult.Pass
		end, false, SWITCH_KEY)
	else
		ContextActionService:UnbindAction(SWITCH_ACTION)
	end
end

-- WHETHER THE KEY IS BOUND RIGHT NOW, for a spec and for a probe: the binding is the claim, so it
-- has to be readable rather than believed.
function PadPanel.switchKeyBound(): boolean
	return switchKeyBound
end

function PadPanel.switchKeyName(): string
	return SWITCH_KEY.Name
end

-- WHAT THE BLOCK SAYS, for a spec and for a console probe -- `rowText`'s own seam.
function PadPanel.switchText(): { string }
	if roleSwitch == nil or switchBlock == nil or not (switchBlock :: Frame).Visible then
		return {}
	end
	return {
		(switchEyebrow :: TextLabel).Text,
		(switchKeyChip :: TextLabel).Text,
		roleSwitch.words[LobbyData.ROLE_WISH.HUNTER].Text,
		roleSwitch.words[LobbyData.ROLE_WISH.BEATER].Text,
		(switchCaption :: TextLabel).Text,
	}
end

function PadPanel.roleWish(): string?
	return wish
end

-- WHICH HALF IS LIT, off the BUILT control rather than off the value it was told -- so a spec can
-- tell "the panel knows" from "the panel drew it".
function PadPanel.roleLit(): string?
	return if roleSwitch == nil then nil else roleSwitch.selected
end

function PadPanel.render()
	stats.renders += 1
	local frame = panel
	if frame == nil then
		return
	end
	-- `dialogShown` AND NOT `ask ~= nil` SINCE TASK 246: the next drive's card is drawn in this
	-- dialog's own rectangle, so one of the two has to yield -- and it is this one, because a man the
	-- next drive already has has answered this dialog's question already.
	frame.Visible = PadPanel.dialogShown()
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
	-- ...AND THE ROLE BLOCK GOES DIM WITH THE ROWS (task 229), because `sent` is exactly what makes
	-- the switch unusable: `ASKED FOR ALREADY` for a party of two or more, `NO BEATERS THIS DRIVE`
	-- for a party of one. **DISABLED AND NOT HIDDEN**: hiding it here would make the dialog jump
	-- 119 px under the player's thumb while the truck is loading.
	PadPanel.renderRole()
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

-- ---------------------------------------------------------------- the next drive's card (task 246)
--
-- KAREN, 2026-10-23: *"we need continues game so after drive new drive imidiatly after same amount
-- seconds and who has licesne can select who he can be next round if dont then oposit previuos
-- round"*.
--
-- IT IS DRAWN IN THE SIZE DIALOG'S OWN RECTANGLE -- same width, same bottom edge, same `ZIndex`,
-- the same three functions -- and the two are NEVER up together: `PadPanel.dialogShown` is false
-- while this card is up, and this module owns both `Visible`s. The reason is stated in
-- `Lobby.CONFIG.PADS.NEXT`'s own comment: they are the same question (*"which drive are you going
-- on"*), a man the next drive already has does not need to be asked how big a party he wants, and
-- reusing the rectangle means task 209's banner-overlap arithmetic holds with nothing re-measured
-- and `hud_clarity.spec` gains no band.

export type NextLayout = {
	height: number,
	countY: number,
	switchShown: boolean,
	switchY: number,
	trackY: number,
	trackWidth: number,
	halfWidth: number,
	captionY: number,
	buttonY: number,
	noteY: number,
	hintY: number,
}

-- HOW TALL THE ROLE BLOCK IS ON THIS CARD. It is SHORTER than the dialog's `ROLE.BLOCK_PX` by the
-- rule and the trailing air under it (`RULE_GAP`, `RULE_PX`, `TRAIL_PX`), and that is not a second
-- set of numbers: the rule exists in the dialog to separate the role from the four size rows, and
-- this card has no size rows to separate it from. Everything else is the same row, from the same
-- table, so the control sits at the same height on both surfaces.
local function nextRoleHeight(): number
	return ROLE.EYEBROW_PX + ROLE.GAP_PX + ROLE.TRACK_PX + ROLE.NOTE_GAP + ROLE.NOTE_PX
end

-- EVERY RECTANGLE ON THIS CARD, FROM THE DATA PLUS TWO FACTS. PURE, which is `PadPanel.layoutFor`'s
-- own rule and task 165's lesson: *"asserted ARITHMETICALLY rather than by a screenshot"*.
--
-- THE SWITCH IS SHOWN ON EXACTLY THE SAME CONDITION AS THE DIALOG'S (`roleSelected` plus
-- `switchFitsIn`), through the same two functions, so a man who sees the control on the pad sees it
-- here too, and a 400 px phone that cannot fit it is told so once.
function PadPanel.nextLayoutFor(next_: string?, height: number?): NextLayout
	local shown = PadPanel.roleSelected(next_) ~= nil and PadPanel.switchFitsIn(height)
	local countY = PANEL.HEADER_PX + NEXT.GAP
	local afterCount = countY + NEXT.COUNT_PX
	local switchY = afterCount + NEXT.GAP
	local trackY = switchY + ROLE.EYEBROW_PX + ROLE.GAP_PX
	local captionY = trackY + ROLE.TRACK_PX + ROLE.NOTE_GAP
	local afterRole = if shown then switchY + nextRoleHeight() else afterCount
	local buttonY = afterRole + NEXT.GAP
	local noteY = buttonY + NEXT.BUTTON_PX + 4
	local hintY = noteY + NEXT.NOTE_PX + NEXT.GAP
	local trackWidth = PANEL.WIDTH - 2 * PAD
	return {
		height = hintY + NEXT.HINT_PX + PAD,
		countY = countY,
		switchShown = shown,
		switchY = switchY,
		trackY = trackY,
		trackWidth = trackWidth,
		-- THE DIALOG'S OWN FORMULA, not a copy of its result: `(track - 2*PAD - GAP) / 2`, which is
		-- the one that adds up (see `PadPanel.layoutFor`'s note about the Designer's drawing).
		halfWidth = (trackWidth - 2 * SWITCH.TRACK_PAD - SWITCH.TRACK_GAP) / 2,
		captionY = captionY,
		buttonY = buttonY,
		noteY = noteY,
		hintY = hintY,
	}
end

function PadPanel.nextHeightFor(next_: string?, height: number?): number
	return PadPanel.nextLayoutFor(next_, height).height
end

-- WHAT THE BIG NUMBER SAYS. PURE. `math.ceil`, which is `Hud.startCardSecondsFor`'s own choice and
-- its reason: a countdown that reads 0 for a whole second before it happens has lied for a second.
function PadPanel.nextSecondsFor(secondsLeft: number?): number
	return math.max(0, math.ceil(secondsLeft or 0))
end

-- WHAT THE ONE BUTTON SAYS, and what the line under it says. PURE, both of them, off the SERVER'S
-- word and nothing else -- so the button a player presses and the sentence that explains it can
-- never disagree. One control, because it is one boolean (`NEXT.SIT_OUT` / `NEXT.SIT_IN`).
function PadPanel.nextButtonFor(out: boolean?): string
	return if out == true then NEXT.SIT_IN else NEXT.SIT_OUT
end

function PadPanel.nextNoteFor(out: boolean?): string
	return if out == true then NEXT.NOTE_OUT else NEXT.NOTE_IN
end

-- IS THE CARD UP? PURE AND SERVER-DECIDED: there is a countdown or there is not
-- (`Lobby.secondsLeft`'s contract carried to the screen). The window BEFORE the countdown is armed
-- -- the party collected, somebody still walking home from the line -- is Karen's results scene, and
-- this card is deliberately DOWN for all of it.
function PadPanel.nextShown(): boolean
	return nextLeft ~= nil
end

-- ...AND THEREFORE WHETHER THE SIZE DIALOG IS. PURE, and it is the ONE rule, read by `render` and by
-- the spec: the card wins, because a man the next drive already has has already answered the
-- dialog's question.
function PadPanel.dialogShown(): boolean
	return ask ~= nil and not PadPanel.nextShown()
end

-- WHAT THE CARD SAYS, for a spec and for a console probe -- `switchText`'s own seam.
function PadPanel.nextText(): { string }
	if nextCard == nil or not (nextCard :: Frame).Visible then
		return {}
	end
	return {
		(nextEyebrow :: TextLabel).Text,
		(nextTitle :: TextLabel).Text,
		(nextCount :: TextLabel).Text,
		(nextButtonWord :: TextLabel).Text,
		(nextKeyChip :: TextLabel).Text,
		(nextNote :: TextLabel).Text,
		(nextHint :: TextLabel).Text,
	}
end

function PadPanel.sittingOut(): boolean
	return nextOut
end

function PadPanel.nextFrame(): Frame?
	return nextCard
end

-- WHICH HALF IS LIT ON THE CARD'S OWN SWITCH, off the BUILT control -- `roleLit`'s rule, so a spec
-- can tell "the panel knows" from "the panel drew it", on this surface as well as on the dialog.
function PadPanel.nextRoleLit(): string?
	return if nextRoleSwitch == nil then nil else nextRoleSwitch.selected
end

function PadPanel.sitKeyBound(): boolean
	return sitKeyBound
end

function PadPanel.sitKeyName(): string
	return SIT_KEY.Name
end

local function buildNext(frame: Frame)
	nextCard = frame
	frame.AnchorPoint = PadPanel.anchorPoint()
	-- THE SAME BOTTOM EDGE AS THE DIALOG, from the dialog's own function, so the two surfaces are
	-- one rectangle in one place and the banner's band arithmetic is untouched.
	frame.Position = PadPanel.positionFor()
	frame.ZIndex = PadPanel.zIndex()
	corner(frame, CORNER_PANEL)
	stroke(frame, LOOK.BRASS, 0.74)

	nextEyebrow = label(frame, "Eyebrow", FONT.SANS_SEMI, EYEBROW_SIZE, LOOK.BRASS, 1);
	(nextEyebrow :: TextLabel).Position = UDim2.fromOffset(PAD, 13);
	(nextEyebrow :: TextLabel).Size = UDim2.new(1, -2 * PAD, 0, EYEBROW_SIZE + 3);
	(nextEyebrow :: TextLabel).Text = spaced(NEXT.EYEBROW)

	nextTitle = label(frame, "Title", FONT.OSWALD_SB, TITLE_SIZE, LOOK.PAPER, 1);
	(nextTitle :: TextLabel).Position = UDim2.fromOffset(PAD, 27);
	(nextTitle :: TextLabel).Size = UDim2.new(1, -2 * PAD, 0, TITLE_SIZE + 6);
	(nextTitle :: TextLabel).Text = NEXT.TITLE

	hairline(frame, PANEL.HEADER_PX - HAIRLINE_PX, 1)

	-- THE ONE MOVING NUMBER ON THIS CARD, and it is the only thing on it that is allowed to move
	-- (spec 8.9) because it is a VALUE and not decoration -- the banner's bar's own argument.
	nextCount = label(frame, "Count", FONT.OSWALD_SB, NEXT.COUNT_SIZE, LOOK.BLAZE, 1);
	(nextCount :: TextLabel).Size = UDim2.new(1, -2 * PAD, 0, NEXT.COUNT_PX);
	(nextCount :: TextLabel).TextXAlignment = Enum.TextXAlignment.Center;
	(nextCount :: TextLabel).TextYAlignment = Enum.TextYAlignment.Center;
	(nextCount :: TextLabel).Text = ""

	-- THE ROLE BLOCK, AGAIN, ON THE SURFACE WHERE KAREN ASKED FOR IT: *"who has licesne can select
	-- who he can be next round"*. The control is `ShopPanel`'s, built and painted there -- it is
	-- drawn on three surfaces now, and *"the shop sets the house style"*.
	local block = Instance.new("Frame")
	block.Name = "RoleBlock"
	block.BackgroundTransparency = 1
	block.BorderSizePixel = 0
	block.ZIndex = PANEL.Z_INDEX + 2
	block.Visible = false
	block.Parent = frame
	nextRoleBlock = block

	nextRoleEyebrow = label(block, "RoleEyebrow", FONT.SANS_BOLD, EYEBROW_SIZE + 1, LOOK.FAINT, 3);
	(nextRoleEyebrow :: TextLabel).Text = spaced(ROLE.EYEBROW);
	(nextRoleEyebrow :: TextLabel).Size = UDim2.new(1, -ROLE.KEY_PX, 0, ROLE.EYEBROW_PX)

	-- THE ROLE KEY'S CHIP, right-aligned on the eyebrow's own row -- the dialog's arrangement
	-- exactly, and `T` is bound while THIS card is up as well (`bindSwitchKey`, from `setNext`).
	local roleKey = label(block, "RoleKey", FONT.SANS_BOLD, EYEBROW_SIZE, LOOK.FAINT, 3)
	roleKey.Text = spaced(string.format(ROLE.KEY_HINT, SWITCH_KEY.Name))
	roleKey.AnchorPoint = Vector2.new(1, 0)
	roleKey.Position = UDim2.fromScale(1, 0)
	roleKey.Size = UDim2.fromOffset(ROLE.KEY_PX, ROLE.EYEBROW_PX)
	roleKey.TextXAlignment = Enum.TextXAlignment.Right
	roleKey.TextTruncate = Enum.TextTruncate.AtEnd

	nextRoleSwitch = ShopPanel.buildRoleSwitch(
		block,
		3,
		ROLE.WORD_SIZE,
		{ [LobbyData.ROLE_WISH.HUNTER] = ROLE.HUNTER, [LobbyData.ROLE_WISH.BEATER] = ROLE.BEATER },
		function(which: string)
			PadPanel.sendRoleWish(which)
		end
	)

	nextRoleCaption = label(block, "RoleCaption", FONT.SANS_BOLD, HINT_SIZE, LOOK.FAINT, 3);
	(nextRoleCaption :: TextLabel).Size = UDim2.new(1, 0, 0, ROLE.NOTE_PX);
	(nextRoleCaption :: TextLabel).TextTruncate = Enum.TextTruncate.AtEnd

	-- THE WAY OUT. ONE button, because it is one boolean -- and it carries no text of its own for
	-- the size rows' stated reason: the word and the key chip are child labels, which is the only
	-- way to set two faces at two sizes in one control.
	local button = Instance.new("TextButton")
	button.Name = "SitOut"
	button.AutoButtonColor = false
	button.BackgroundColor3 = PadPanel.LOOK.BUTTON_COLOR
	button.BorderSizePixel = 0
	button.Text = ""
	button.Size = UDim2.fromOffset(PANEL.WIDTH - 2 * PAD, NEXT.BUTTON_PX)
	button.ZIndex = PANEL.Z_INDEX + 2
	button.ClipsDescendants = true
	corner(button, CORNER_ROW)
	stroke(button, PadPanel.LOOK.RIM_COLOR, 0.15)
	nextButtonWord = label(button, "Label", FONT.OSWALD_MD, LABEL_SIZE, LOOK.PAPER, 3);
	(nextButtonWord :: TextLabel).Position = UDim2.fromOffset(PAD, 0);
	(nextButtonWord :: TextLabel).Size = UDim2.new(1, -2 * PAD - NEXT.KEY_PX, 1, 0);
	(nextButtonWord :: TextLabel).TextYAlignment = Enum.TextYAlignment.Center
	nextKeyChip = label(button, "Key", FONT.SANS_BOLD, HINT_SIZE, LOOK.FAINT, 3);
	(nextKeyChip :: TextLabel).AnchorPoint = Vector2.new(1, 0.5);
	(nextKeyChip :: TextLabel).Position = UDim2.new(1, -PAD, 0.5, 0);
	(nextKeyChip :: TextLabel).Size = UDim2.fromOffset(NEXT.KEY_PX, LABEL_SIZE);
	(nextKeyChip :: TextLabel).TextXAlignment = Enum.TextXAlignment.Right;
	(nextKeyChip :: TextLabel).TextYAlignment = Enum.TextYAlignment.Center;
	(nextKeyChip :: TextLabel).Text = spaced(string.format(NEXT.KEY_HINT, SIT_KEY.Name))
	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = PadPanel.LOOK.ROW_HOVER_COLOR
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = PadPanel.LOOK.BUTTON_COLOR
	end)
	button.Activated:Connect(function()
		PadPanel.pressNext()
	end)
	button.Parent = frame
	nextButton = button

	nextNote = label(frame, "Note", FONT.SANS_REG, NOTE_SIZE, LOOK.MUTED, 1);
	(nextNote :: TextLabel).Size = UDim2.new(1, -2 * PAD, 0, NEXT.NOTE_PX);
	(nextNote :: TextLabel).TextTruncate = Enum.TextTruncate.AtEnd

	-- ...AND THIS CARD'S OTHER EXIT, written down for the dialog's own stated reason: there is no
	-- close button, because closing a countdown that is still running would be hiding it.
	nextHint = label(frame, "Hint", FONT.SANS_BOLD, HINT_SIZE, LOOK.FAINT, 1);
	(nextHint :: TextLabel).Size = UDim2.new(1, -2 * PAD, 0, NEXT.HINT_PX);
	(nextHint :: TextLabel).Text = spaced(NEXT.HINT);
	(nextHint :: TextLabel).TextTruncate = Enum.TextTruncate.AtEnd

	PadPanel.relayoutNext()
end

-- THE ONE WRITER OF EVERY RECTANGLE ON THIS CARD, from the pure `nextLayoutFor` -- `relayout`'s
-- arrangement one surface along, and for its stated reason: `buildNext` writes the Ys that cannot
-- move (the header's) and this writes every one that can, so there is exactly one place that can put
-- a row in the wrong place.
function PadPanel.relayoutNext()
	local frame = nextCard
	if frame == nil then
		return
	end
	local layout = PadPanel.nextLayoutFor(wish, screenHeight)
	frame.Size = UDim2.fromOffset(PadPanel.widthFor(), layout.height)
	if nextCount ~= nil then
		(nextCount :: TextLabel).Position = UDim2.fromOffset(PAD, layout.countY)
	end
	if nextRoleBlock ~= nil then
		local block = nextRoleBlock :: Frame
		block.Visible = layout.switchShown
		block.Position = UDim2.fromOffset(PAD, layout.switchY)
		block.Size = UDim2.fromOffset(layout.trackWidth, nextRoleHeight())
	end
	if nextRoleSwitch ~= nil then
		nextRoleSwitch.track.Visible = layout.switchShown
		nextRoleSwitch.track.Position = UDim2.fromOffset(0, layout.trackY - layout.switchY)
		nextRoleSwitch.track.Size = UDim2.fromOffset(layout.trackWidth, ROLE.TRACK_PX)
	end
	if nextRoleCaption ~= nil then
		(nextRoleCaption :: TextLabel).Position = UDim2.fromOffset(0, layout.captionY - layout.switchY)
	end
	if nextButton ~= nil then
		(nextButton :: TextButton).Position = UDim2.fromOffset(PAD, layout.buttonY)
	end
	if nextNote ~= nil then
		(nextNote :: TextLabel).Position = UDim2.fromOffset(PAD, layout.noteY)
	end
	if nextHint ~= nil then
		(nextHint :: TextLabel).Position = UDim2.fromOffset(PAD, layout.hintY)
	end
end

-- WHEN THE NEXT DRIVE STARTS AND WHETHER HE HAS ASKED TO MISS IT. TOLD, both of them, out of the one
-- evaluation the Hud already runs -- the seconds converted from `DHNextDriveAt` by the same
-- `Lobby.secondsLeft` the pad's countdown goes through, and the boolean read straight off
-- `DHNextDriveOut`. This module reads no attribute and holds no clock (`setLeaving`'s contract).
--
-- THE SECONDS ARE NOT EDGE-TRIGGERED AND CANNOT BE: they change every frame, which is the point of
-- them. Everything written from them compares first, inside `renderNext`.
function PadPanel.setNext(secondsLeft: number?, out: boolean?)
	local wasShown = PadPanel.nextShown()
	nextLeft = if type(secondsLeft) == "number" then secondsLeft else nil
	nextOut = out == true
	local isShown = PadPanel.nextShown()
	if isShown and not wasShown then
		stats.nextOpens += 1
		-- THE MOUSE, THE TRIGGER AND THE TWO KEYS, through the doors that already exist, reason-keyed
		-- so this releases exactly its own request (`setAsk`'s shape, tag `"nextdrive"`). The role
		-- switch's `T` is bound here as well as on the pad, because the control is on BOTH surfaces
		-- -- `bindSwitchKey` is idempotent, which is what makes two call sites safe.
		if Cursor ~= nil then
			Cursor.requestFree("nextdrive")
		end
		if WeaponInput ~= nil then
			WeaponInput.requestHold("nextdrive")
		end
		PadPanel.bindSitKey(true)
		PadPanel.bindSwitchKey(true)
	elseif not isShown and wasShown then
		stats.nextCloses += 1
		if Cursor ~= nil then
			Cursor.release("nextdrive")
		end
		if WeaponInput ~= nil then
			WeaponInput.releaseHold("nextdrive")
		end
		PadPanel.bindSitKey(false)
		-- ...AND `T` GOES BACK ONLY IF NO PAD DIALOG IS UP, because that surface binds it too. One
		-- boolean decides, which is why `bindSwitchKey` takes one rather than counting requests.
		PadPanel.bindSwitchKey(ask ~= nil)
	end
	PadPanel.renderNext()
	-- THE DIALOG'S OWN VISIBILITY IS THIS CARD'S BUSINESS TOO, because the two share a rectangle:
	-- `render` reads `dialogShown`, so the card appearing closes the dialog in the same frame.
	PadPanel.render()
end

function PadPanel.renderNext()
	local frame = nextCard
	if frame == nil then
		return
	end
	local shown = PadPanel.nextShown()
	if frame.Visible ~= shown then
		frame.Visible = shown
	end
	if not shown then
		return
	end
	-- WRITTEN ONLY WHEN IT DIFFERS, every one of them: this renderer is called every frame, which is
	-- what the seconds need, so the writes are edge-triggered INSIDE instead (`renderLeaving`'s
	-- discipline, and `Lobby.setRespawn`'s on the server's side of the same system).
	local count = tostring(PadPanel.nextSecondsFor(nextLeft))
	if nextCount ~= nil and (nextCount :: TextLabel).Text ~= count then
		(nextCount :: TextLabel).Text = count
	end
	local word = spaced(PadPanel.nextButtonFor(nextOut))
	if nextButtonWord ~= nil and (nextButtonWord :: TextLabel).Text ~= word then
		(nextButtonWord :: TextLabel).Text = word
	end
	local note = spaced(PadPanel.nextNoteFor(nextOut))
	if nextNote ~= nil and (nextNote :: TextLabel).Text ~= note then
		(nextNote :: TextLabel).Text = note
	end
	-- THE BUTTON WEARS THE ONE ORANGE THING ON THIS CARD ONLY WHEN HE IS OUT, because then coming
	-- back is the thing that happens if he does anything at all -- the size rows' default-marker
	-- argument (*"what the orange marks is the row that happens if you do nothing"*) read the other
	-- way round. While he is IN, the button is a row at rest and the NUMBER is the orange thing.
	if nextButton ~= nil then
		local tint = if nextOut then LOOK.BLAZE_LO else PadPanel.LOOK.BUTTON_COLOR
		if (nextButton :: TextButton).BackgroundColor3 ~= tint then
			(nextButton :: TextButton).BackgroundColor3 = tint
		end
	end
	PadPanel.renderRole()
end

-- ONE PRESS, ONE MESSAGE. PUBLIC and named for `PadPanel.press`' stated reason: a spec cannot fire
-- `GuiButton.Activated` and the harness cannot synthesise a tap, so this is the seam that makes the
-- button testable at all -- and what it proves is the ACTION, not the touch. That limit is reported
-- in the review request, not papered over.
--
-- IT IS A TOGGLE off the SERVER'S word, so a double press is in-out-in and never two "out"s.
--
-- WHICH WORD THAT IS, AS A PURE FUNCTION, for `roleSelected`'s and `otherRole`'s stated reason: the
-- decision is then arithmetic a spec asserts, rather than something a wiretap would have to catch.
function PadPanel.nextPressWord(out: boolean?): string
	return if out == true then LobbyData.NEXT_WORD.IN else LobbyData.NEXT_WORD.OUT
end

function PadPanel.pressNext(): boolean
	return PadPanel.sendNext(PadPanel.nextPressWord(nextOut))
end

-- IT SENDS NOTHING FOR A WORD THAT IS NOT IN `Lobby.NEXT_WORD`, and nothing at all while no
-- countdown is up: the server refuses both anyway (`bad-request` and `no-party`), and a client that
-- sent one would be this client telling the server a lie about its own state.
--
-- NO OPTIMISTIC REDRAW, for `sendRoleWish`'s stated reason: the server writes the attribute INSIDE
-- `Lobby.onNextRequest`, so the round trip is one network hop -- not the 3.65 s the pad's 10 Hz scan
-- measured -- and a button that lit itself would be a client holding an opinion about a value whose
-- whole security is that it does not.
function PadPanel.sendNext(which: string): boolean
	if not LobbyData.nextAllowed(which) or not PadPanel.nextShown() then
		stats.nextBlocked += 1
		return false
	end
	if remotes ~= nil and remotes.NextRequest ~= nil then
		remotes.NextRequest:FireServer({ next = which })
		stats.nextSent += 1
		return true
	end
	stats.nextBlocked += 1
	return false
end

-- THE KEY IS BOUND ONLY WHILE THE CARD IS UP, which is `bindSwitchKey`'s arrangement and its stated
-- reason: `Y` belongs to the player again the instant the drive takes him, and a card that never
-- appeared never took a key at all. Idempotent, so two call sites cannot stack two actions on it.
function PadPanel.bindSitKey(on: boolean)
	if on == sitKeyBound then
		return
	end
	sitKeyBound = on
	if on then
		ContextActionService:BindAction(SIT_ACTION, function(_name, state)
			if state == Enum.UserInputState.Begin then
				PadPanel.pressNext()
			end
			-- `Pass`, DELIBERATELY, and it is `bindSwitchKey`'s rule applied again: this card must
			-- not swallow an input. Nothing else binds `Y`, so passing costs nothing today and is
			-- the safe answer the day something does.
			return Enum.ContextActionResult.Pass
		end, false, SIT_KEY)
	else
		ContextActionService:UnbindAction(SIT_ACTION)
	end
end

function PadPanel.start(frame: Frame, collaborators: any)
	if started then
		return
	end
	started = true
	local bag = collaborators or {}
	Cursor = bag.Cursor
	WeaponInput = bag.Input
	-- **THE BAG MAY NOT UN-TELL WHAT `setRemotes` ALREADY TOLD (task 244, and it is Karen's defect
	-- of 2026-10-22: *"I still can't select before game who I want to be"*).** `Hud.start` resolves
	-- `ReplicatedStorage.Lobby` through `Hud.whenReady` BEFORE it starts this panel, and
	-- `whenReady` calls its callback SYNCHRONOUSLY when the module is already there -- which it
	-- always is, because Rojo replicates it with the place. So `PadPanel.setRemotes(Lobby.remotes())`
	-- ran at line 1 and this line then wrote `nil` over it, because the Hud's bag carries no
	-- `remotes` key: the dialog's ONE outbound door has been shut since task 182 built it.
	--
	-- MEASURED on Karen's own path in the live Forest Test, 2026-10-22, with a wiretap on
	-- `Lobby.Remotes` and a REAL OS mouse click on the BEATER half: the half took the click (its
	-- press tint was drawn, `BackgroundTransparency` 0.68 = `ROLE.PRESS_TRANSPARENCY`), and
	-- `RoleRequest` never reached the server. A real click on the `1 / 1` row sent no `PadRequest`
	-- either -- that half of it was INVISIBLE because the pad falls back to the default size after
	-- `PADS.PICK_TIMEOUT_SECONDS`, so a dead button and a slow one look the same from the outside.
	--
	-- `setRemotes` IS THE ONE WRITER, and `start` now only seeds it for a caller that brought one
	-- (`pad_panel.spec` passes `remotes = nil` deliberately and still gets a dialog that sends
	-- nothing).
	if bag.remotes ~= nil then
		remotes = bag.remotes
	end
	build(frame)
	frame.Visible = false
	-- THE BANNER'S FRAME IS OPTIONAL, for the reason every collaborator in this Hud is: a spec that
	-- takes the panel over hands it one frame (`pad_panel.spec`'s own case), and a module that threw
	-- without the second would make the dialog untestable to add a banner to it.
	if bag.leaving ~= nil then
		buildBanner(bag.leaving);
		(bag.leaving :: Frame).Visible = false
	end
	-- ...AND THE NEXT DRIVE'S CARD (task 246), optional for the same reason the banner is: a spec
	-- that takes the panel over hands it one frame, and a module that threw without the third would
	-- make the dialog untestable to add a card to it.
	if bag.nextDrive ~= nil then
		buildNext(bag.nextDrive);
		(bag.nextDrive :: Frame).Visible = false
	end
	PadPanel.render()
	PadPanel.renderLeaving()
	PadPanel.renderNext()
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
	-- ...AND THE ROLE BLOCK (task 229, review round 1 note 3). This function's own contract is
	-- *"nothing on screen, nothing held"*, and a stale `wish` would make the first `setRoleWish`
	-- after a restart early-return and skip the first `renderRole` -- a block drawn from a value
	-- this module was told before it was stopped.
	wish = nil
	team = nil
	screenHeight = nil
	-- ...AND THE KEY (task 244). `setAsk(nil)` above releases it on the dialog's own edge; this is
	-- the belt for a `stop` called while no dialog was up, so no restart can leave `T` bound to a
	-- panel that no longer exists -- *"nothing on screen, nothing held"*, and a bound key is held.
	PadPanel.bindSwitchKey(false)
	switchBlock = nil
	switchEyebrow = nil
	switchKeyChip = nil
	switchCaption = nil
	switchRule = nil
	roleSwitch = nil
	hint = nil
	-- ...AND THE NEXT DRIVE'S CARD (task 246). Same contract -- *"nothing on screen, nothing held"* --
	-- and `Y` is held, so it is released here as well as on the card's own edge.
	PadPanel.bindSitKey(false)
	nextLeft = nil
	nextOut = false
	nextEyebrow = nil
	nextTitle = nil
	nextCount = nil
	nextButton = nil
	nextButtonWord = nil
	nextKeyChip = nil
	nextNote = nil
	nextHint = nil
	nextRoleBlock = nil
	nextRoleEyebrow = nil
	nextRoleCaption = nil
	nextRoleSwitch = nil
	table.clear(buttons)
	table.clear(notes)
	empty(panel)
	empty(banner)
	empty(nextCard)
	panel = nil
	banner = nil
	nextCard = nil
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
