-- RangePanel: the lobby shooting range's MENU. Six option rows, a CONFIRM bar, and the two doors it
-- borrows by the tag "range" -- `ShopPanel.setOpen` with one word changed (design 7.1, 8.5).
--
-- Design: docs/design/shooting-range.md sections 7.1, 7.3, 8.5, 11.2. Task 298 phase B, step B4.
--
-- Owner (CLAUDE.md rule 3): this file is the one writer of its own Frame's children and of its own
-- `Visible`. It owns NO option list -- every row is the SERVER's, through `setState` (design 7.3) --
-- and no record: the board is `RangeBoard.luau` and the record is `ServerScriptService.Range`'s.
--
-- `GuiButton.Modal` IS NOT USED: `src/client/Weapon/Input.luau` refuses it as a second writer of
-- `MouseBehavior`. The mouse is freed by `Cursor.requestFree("range")` and nothing else.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RangeData = require(ReplicatedStorage:WaitForChild("Range"))

local RangePanel = {}

RangePanel.LOOK = {
	PANEL = Color3.fromRGB(26, 28, 24),
	ROW = Color3.fromRGB(42, 46, 40),
	ROW_PICKED = Color3.fromRGB(96, 124, 72),
	TEXT = Color3.fromRGB(232, 232, 224),
	LABEL = Color3.fromRGB(168, 172, 160),
	CONFIRM = Color3.fromRGB(120, 152, 88),
	-- TALL ENOUGH TO SWALLOW THE INSET AND ANY ROUNDING: the measured miss was 58 px, so a bar of
	-- 46 could not be positioned to contain the centre on every screen; 140 can, with margin.
	CONFIRM_HEIGHT = 140,
	WIDTH = 560,
	HEIGHT = 640,
	Z_INDEX = 14,
}

-- THE SIX ROWS, IN THE ORDER THE MENU SHOWS THEM. The option names are the door's own
-- (`Range.OPTIONS`), because the word the row sends must be the word the server whitelists.
RangePanel.ROWS = {
	{ option = "species", label = "ANIMAL" },
	{ option = "kind", label = "KIND" },
	{ option = "pace", label = "PACE" },
	{ option = "weapon", label = "WEAPON" },
	{ option = "ammo", label = "CARTRIDGE" },
	{ option = "distanceStuds", label = "DISTANCE" },
}

local panel: Frame? = nil
local prompt: any = nil
local promptConnection: any = nil
local Cursor: any = nil
local WeaponInput: any = nil
local send: ((any) -> ())? = nil
local open = false
local near = false
local enabled = true
local state: any = nil
local picked: { [string]: any } = {}
local buttons: { [string]: { any } } = {}
local confirmButton: TextButton? = nil
local leaveButton: TextButton? = nil
local stats = { opens = 0, closes = 0, sends = 0, prompts = 0, picks = 0, keys = 0, swallowed = 0, leaves = 0 }
-- THE KEY, BOUND WHILE HE IS AT THE SPOT (task 308 bug 2).
RangePanel.KEY_ACTION = "DrivenHunt.Range.Toggle"
RangePanel.KEY = Enum.KeyCode.E
local keyBound = false
-- IS THE ENGINE OFFERING ITS OWN PROMPT RIGHT NOW? Told by `ProximityPromptService`, and the one
-- thing that decides which of the two doors answers a press (see `onKeyPressed`).
local promptShown = false
local shownConnections: { any } = {}
-- IS THE ENGINE OFFERING THE RANGE'S **CLIMB** PROMPT RIGHT NOW? (step B10, item 6.) That prompt is
-- on `E` too, at the ladder's foot -- and MEASURED there, the station's own RANGE prompt is 11.95
-- studs away, inside its `MaxActivationDistance` of 12. So `nearestPrompt` answers, this panel binds
-- `E`, and one press would both climb AND open the menu. While the climb prompt is shown this
-- panel's key stands down -- the same rule `onKeyPressed` already applies to its OWN prompt, and
-- for the same reason: the engine is already answering that key.
local climbShown = false
local climbConnections: { any } = {}

-- THE CONFIRM BAR MUST CONTAIN THE VIEWPORT CENTRE, which is the one point the input replay can
-- click (design 11.3) -- and MEASURED LIVE on 2026-10-27 it did not: the HUD's `ScreenGui` carries
-- the top bar's inset, so a bar centred at scale 0.5 sat 58 px above the centre of the screen.
-- `GuiService:GetGuiInset()` is that offset, read here and nowhere else.
function RangePanel.confirmPosition(): UDim2
	local inset = Vector2.zero
	local ok, top = pcall(function()
		return GuiService:GetGuiInset()
	end)
	if ok and top ~= nil then
		inset = top
	end
	return UDim2.new(0.5, 0, 0.5, math.floor(inset.Y / 2 + 0.5))
end

-- THE STRIP IS 416 px WIDE (`WIDTH` 560 less the 128 label gutter and the 16 right margin) and
-- B4's PACE row offers SEVEN values, which at the shipped 94 px pitch would run 238 px off the
-- panel. The pitch is DERIVED from the count instead: the shipped 94 while it fits, then as wide as
-- the strip allows. Four values still measure 94 / 90, so every shipped row is bit-for-bit today's.
RangePanel.STRIP_WIDTH = RangePanel.LOOK.WIDTH - 144
RangePanel.BUTTON_PITCH = 94
RangePanel.BUTTON_GAP = 4

function RangePanel.buttonLayout(count: number): (number, number)
	if type(count) ~= "number" or count < 1 then
		return RangePanel.BUTTON_PITCH, RangePanel.BUTTON_PITCH - RangePanel.BUTTON_GAP
	end
	local pitch = math.min(RangePanel.BUTTON_PITCH, math.floor(RangePanel.STRIP_WIDTH / count))
	return pitch, math.max(1, pitch - RangePanel.BUTTON_GAP)
end

function RangePanel.panelSize(): UDim2
	return UDim2.fromOffset(RangePanel.LOOK.WIDTH, RangePanel.LOOK.HEIGHT)
end

function RangePanel.isOpen(): boolean
	return open
end

function RangePanel.stats()
	local out = table.clone(stats)
	out.open = open
	out.near = near
	return out
end

function RangePanel.frame(): Frame?
	return panel
end

-- WHAT EACH ROW OFFERS, read off the state the SERVER sent and never typed here (design 7.3).
-- `{ value, label }` pairs: the value crosses the wire, the label is what the player reads.
function RangePanel.valuesFor(option: string): { { value: any, label: string } }
	local out = {}
	local lists = if type(state) == "table" then state.lists else nil
	if type(lists) ~= "table" then
		return out
	end
	if option == "species" and type(lists.species) == "table" then
		for _, name in ipairs(lists.species) do
			table.insert(out, { value = name, label = string.upper(tostring(name)) })
		end
	elseif option == "kind" and type(lists.kinds) == "table" then
		for _, name in ipairs(lists.kinds) do
			table.insert(out, { value = name, label = string.upper(tostring(name)) })
		end
	elseif option == "pace" and type(lists.pace) == "table" then
		for _, word in ipairs(lists.pace) do
			table.insert(out, { value = word, label = string.upper(tostring(word)) })
		end
	elseif option == "weapon" and type(lists.weapons) == "table" then
		for _, row in ipairs(lists.weapons) do
			table.insert(out, { value = row.id, label = string.upper(tostring(row.label or row.id)) })
		end
	elseif option == "ammo" and type(lists.weapons) == "table" then
		-- THE LOADS THE CHOSEN GUN REALLY HAS, labelled with its own `AMMO_LABEL` -- the same pair
		-- the Hud's ammo chip reads. A gun with one load shows one row, which is the truth.
		local wanted = RangePanel.selected("weapon")
		for _, row in ipairs(lists.weapons) do
			if row.id == wanted and type(row.ammo) == "table" then
				for _, kind in ipairs(row.ammo) do
					local label = (type(row.ammoLabel) == "table" and row.ammoLabel[kind]) or kind
					table.insert(out, { value = kind, label = string.upper(tostring(label)) })
				end
			end
		end
	elseif option == "distanceStuds" and type(lists.distances) == "table" then
		-- LABELLED FROM WHERE HE IS STANDING, so the lit chip and the board print the SAME number
		-- (306k item 4): on the deck the shot is `STAND.backStuds` longer, the board said
		-- `DISTANCE 139 studs` and the chips said 107 / 125 / 179. The VALUE stays the pick the
		-- server's whitelist knows -- only the word changes.
		local record = if type(state) == "table" then state.record else nil
		local position = if type(record) == "table" then record.position else nil
		for _, studs in ipairs(lists.distances) do
			local shown = RangeData.distanceFor(studs, position, RangeData.LAYOUT)
			table.insert(out, { value = studs, label = RangeData.distanceText(shown) })
		end
	end
	return out
end

-- WHAT IS SELECTED: this player's own pick if he made one, else the TRIAL THE SERVER IS RUNNING.
-- One answer, so the lit row is never a wish the server refused.
function RangePanel.selected(option: string): any
	local mine = picked[option]
	if mine ~= nil then
		return mine
	end
	local record = if type(state) == "table" then state.record else nil
	if type(record) == "table" then
		if option == "distanceStuds" then
			-- THE CHIP IT WAS PICKED FROM, not the effective distance: on the deck the record
			-- carries 139 and no chip holds that value, so nothing lit (306k item 4).
			return RangeData.distancePickOf(record, RangeData.LAYOUT)
		end
		return record[option]
	end
	return nil
end

function RangePanel.select(option: string, value: any)
	-- THE SAME WHITELIST THE SERVER'S DOOR ASKS (`Lobby.roleAllowed`'s rule): the sender asks it of
	-- its own argument, so "which words are legal" has one answer and a bad pick never leaves here.
	local lists = if type(state) == "table" then state.lists else nil
	local against = if option == "ammo" then { weapon = RangePanel.selected("weapon") } else lists
	if not RangeData.optionAllowed(option, value, against) then
		return
	end
	picked[option] = value
	if option == "weapon" then
		-- A NEW GUN'S LOADS ARE NOT THE OLD GUN'S: the cartridge pick goes with it (design 7.3).
		picked.ammo = nil
	elseif option == "species" then
		-- ...AND A NEW ANIMAL'S KINDS ARE NOT THE OLD ANIMAL'S. Without this the KIND row's stale
		-- boar word rode along with a deer and the server refused the whole request, for ever
		-- (round 2, finding 1).
		picked.kind = nil
	end
	stats.picks += 1
	RangePanel.render()
end

-- WHICH STATION THIS MENU IS, TOLD by `Hud.step` -- the one evaluation that already resolves which
-- prompt he is standing at (`setPrompt`'s own caller). It used to be the literal 1 in the two
-- senders below, so every one of the six menus picked station 1's trial (306b note (i)).
local station = { spot = 1, position = nil :: string? }

function RangePanel.setStation(spot: number?, position: string?)
	station.spot = if type(spot) == "number" then spot else 1
	station.position = position
end

function RangePanel.stationOf(): (number, string?)
	return station.spot, station.position
end

-- THE ONE SENDER. Nothing else in this file sends, and a request is only ever this shape.
function RangePanel.confirm(): boolean
	local out: any = { spot = station.spot, go = true }
	for _, row in ipairs(RangePanel.ROWS) do
		out[row.option] = picked[row.option]
	end
	local sender = send
	if sender == nil then
		return false
	end
	sender(out)
	stats.sends += 1
	-- AND THE MENU CLOSES ON THE CONFIRM EDGE (Director's default for Karen, 2026-10-27 night; the
	-- proof found it still open behind the released target, frame 11). `setOpen(false)` is the one
	-- door-closer: it hands back the cursor and the input hold under the same reason key.
	RangePanel.setOpen(false)
	return true
end

-- HE LEAVES AND IT ENDS (task 319; Karen, 2026-10-31: *"I also can leave then end"*). One word to
-- the SAME door the confirm bar uses -- the server clears his animal and releases no more until he
-- asks -- and the menu closes on this edge for the reason the confirm bar does.
function RangePanel.leave(): boolean
	local sender = send
	if sender == nil then
		return false
	end
	sender({ spot = station.spot, leave = true })
	stats.sends += 1
	stats.leaves += 1
	RangePanel.setOpen(false)
	return true
end

function RangePanel.reset(): boolean
	local sender = send
	if sender == nil then
		return false
	end
	sender({ spot = station.spot, reset = true })
	stats.sends += 1
	return true
end

-- ------------------------------------------------------------------ the frame
--
-- EVERY CHILD CARRIES `Z_INDEX + 1` (a button `+ 2`). With `ZIndexBehavior.Sibling` a child's
-- ZIndex is compared globally, so children left at the default 1 draw BEHIND a panel at 14 --
-- measured in DEV on 2026-10-27, where the menu photographed as an empty black box.

local function rowLabel(parent: Frame, text: string, y: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(16, y)
	label.Size = UDim2.fromOffset(104, 24)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = RangePanel.LOOK.LABEL
	label.ZIndex = RangePanel.LOOK.Z_INDEX + 1
	label.Text = text
	label.Parent = parent
	return label
end

function RangePanel.build(root: Frame)
	panel = root
	buttons = {}
	for _, child in ipairs(root:GetChildren()) do
		child:Destroy()
	end

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -32, 0, 24)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = RangePanel.LOOK.TEXT
	title.ZIndex = RangePanel.LOOK.Z_INDEX + 1
	title.Text = "SHOOTING RANGE"
	title.Parent = root

	for index, row in ipairs(RangePanel.ROWS) do
		local y = 44 + (index - 1) * 34
		rowLabel(root, row.label, y)
		local strip = Instance.new("Frame")
		strip.Name = row.option
		strip.BackgroundTransparency = 1
		strip.Position = UDim2.fromOffset(128, y)
		strip.Size = UDim2.new(1, -144, 0, 26)
		strip.ZIndex = RangePanel.LOOK.Z_INDEX + 1
		strip.Parent = root
		buttons[row.option] = {}
	end

	-- THE CONFIRM BAR AT THE PANEL'S EXACT CENTRE, and that is a TEST CONSTRAINT and not a taste:
	-- the panel is centred on screen, so this button CONTAINS THE VIEWPORT CENTRE at any size --
	-- which is the one point the input replay can click (design 11.3).
	local confirm = Instance.new("TextButton")
	confirm.Name = "Confirm"
	confirm.AnchorPoint = Vector2.new(0.5, 0.5)
	confirm.Position = RangePanel.confirmPosition()
	confirm.Size = UDim2.fromOffset(300, RangePanel.LOOK.CONFIRM_HEIGHT)
	confirm.BackgroundColor3 = RangePanel.LOOK.CONFIRM
	confirm.BorderSizePixel = 0
	confirm.Font = Enum.Font.GothamBold
	confirm.TextSize = 16
	confirm.TextColor3 = RangePanel.LOOK.TEXT
	confirm.ZIndex = RangePanel.LOOK.Z_INDEX + 2
	confirm.Text = "RELEASE THE TARGET"
	confirm.AutoButtonColor = true
	confirm.Parent = root
	confirm.Activated:Connect(function()
		RangePanel.confirm()
	end)
	confirmButton = confirm

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.BackgroundTransparency = 1
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.new(0.5, 0, 0.5, RangePanel.LOOK.CONFIRM_HEIGHT / 2 + 8)
	hint.Size = UDim2.new(1, -32, 0, 40)
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 12
	hint.TextWrapped = true
	hint.TextColor3 = RangePanel.LOOK.LABEL
	hint.ZIndex = RangePanel.LOOK.Z_INDEX + 1
	hint.Text = "The range is free: every gun, endless cartridges, no licence. Nothing here is scored."
	hint.Parent = root

	-- THE WAY OUT (task 319), IN THE PANEL'S TOP-RIGHT CORNER. Two places it may not be, both
	-- MEASURED on screen in her place: over the viewport centre, which belongs to the confirm bar
	-- (design 11.3), and under the BOARD, which draws over the panel's bottom strip -- the first
	-- frame of this button, 56 px below the bar, came out greyed behind "THE BOARD".
	local leave = Instance.new("TextButton")
	leave.Name = "Leave"
	leave.AnchorPoint = Vector2.new(1, 0)
	leave.Position = UDim2.new(1, -16, 0, 8)
	leave.Size = UDim2.fromOffset(180, 28)
	leave.BackgroundColor3 = RangePanel.LOOK.ROW
	leave.BorderSizePixel = 0
	leave.Font = Enum.Font.GothamBold
	leave.TextSize = 14
	leave.TextColor3 = RangePanel.LOOK.LABEL
	leave.ZIndex = RangePanel.LOOK.Z_INDEX + 2
	leave.Text = "LEAVE THE RANGE"
	leave.AutoButtonColor = true
	leave.Parent = root
	leave.Activated:Connect(function()
		RangePanel.leave()
	end)
	leaveButton = leave

	RangePanel.render()
end

-- ONE BUTTON PER VALUE, rebuilt when the list CHANGES and repainted otherwise: the lists come from
-- the server and a repaint per frame would drop the click the player is making.
function RangePanel.render()
	local root = panel
	if root == nil then
		return
	end
	for _, row in ipairs(RangePanel.ROWS) do
		local strip = root:FindFirstChild(row.option)
		if strip ~= nil then
			local values = RangePanel.valuesFor(row.option)
			local existing = buttons[row.option] or {}
			if #existing ~= #values then
				for _, button in ipairs(existing) do
					button:Destroy()
				end
				existing = {}
				local pitch, width = RangePanel.buttonLayout(#values)
				for index, entry in ipairs(values) do
					local button = Instance.new("TextButton")
					button.Name = row.option .. tostring(index)
					button.Position = UDim2.fromOffset((index - 1) * pitch, 0)
					button.Size = UDim2.fromOffset(width, 26)
					button.BorderSizePixel = 0
					button.Font = Enum.Font.Gotham
					button.TextSize = 12
					button.TextColor3 = RangePanel.LOOK.TEXT
					button.ZIndex = RangePanel.LOOK.Z_INDEX + 2
					button.AutoButtonColor = true
					button.Parent = strip
					button.Activated:Connect(function()
						RangePanel.select(row.option, entry.value)
					end)
					table.insert(existing, button)
				end
				buttons[row.option] = existing
			end
			local selected = RangePanel.selected(row.option)
			for index, button in ipairs(existing) do
				local entry = values[index]
				if entry ~= nil then
					button.Text = entry.label
					button.BackgroundColor3 = if entry.value == selected
						then RangePanel.LOOK.ROW_PICKED
						else RangePanel.LOOK.ROW
				end
			end
		end
	end
end

-- WHAT A SPEC READS INSTEAD OF A SCREENSHOT (design 8.5).
function RangePanel.rowText(): { string }
	local out = {}
	for _, row in ipairs(RangePanel.ROWS) do
		local values = RangePanel.valuesFor(row.option)
		local words = {}
		local selected = RangePanel.selected(row.option)
		for _, entry in ipairs(values) do
			table.insert(words, if entry.value == selected then "[" .. entry.label .. "]" else entry.label)
		end
		table.insert(out, row.label .. ": " .. table.concat(words, " "))
	end
	return out
end

-- THE BUTTON'S REAL RECTANGLE, for the live scenario's own assertion (design 11.3): the spec checks
-- that the point the replay clicked lies INSIDE this before it asserts the click arrived.
function RangePanel.rowRect(option: string, index: number): (Vector2?, Vector2?)
	if option == "confirm" or option == "leave" then
		local button = if option == "confirm" then confirmButton else leaveButton
		if button == nil then
			return nil, nil
		end
		return button.AbsolutePosition, button.AbsoluteSize
	end
	local list = buttons[option]
	local button = if list ~= nil then list[index] else nil
	if button == nil then
		return nil, nil
	end
	return button.AbsolutePosition, button.AbsoluteSize
end

-- ------------------------------------------------------------------ the doors, by tag "range"

function RangePanel.setOpen(next_: boolean)
	if open == next_ then
		return
	end
	open = next_
	local root = panel
	if root then
		root.Visible = open
	end
	if open then
		stats.opens += 1
		-- THE MOUSE AND THE TRIGGER, through the two doors that already exist: `requestFree` is what
		-- lets him click a row in first person, `requestHold` is what stops that click firing the
		-- gun. Both are reason-keyed, so the range releases exactly its own request (design 7.1).
		if Cursor ~= nil then
			Cursor.requestFree("range")
		end
		if WeaponInput ~= nil then
			WeaponInput.requestHold("range")
		end
		RangePanel.render()
	else
		stats.closes += 1
		if Cursor ~= nil then
			Cursor.release("range")
		end
		if WeaponInput ~= nil then
			WeaponInput.releaseHold("range")
		end
	end
end

-- IS HE ON THE MAT? TOLD to this module, never read here, and IT ONLY EVER CLOSES --
-- `ShopPanel.setNear`'s rule: walking up opens nothing, the prompt is the one way in.
function RangePanel.setNear(next_: boolean)
	next_ = next_ == true and enabled
	if near == next_ then
		return
	end
	near = next_
	RangePanel.bindKey(near)
	if not near then
		RangePanel.setOpen(false)
	end
end

-- THE RANGE'S PROMPT, edge-triggered on the Instance, accepting anything with a `Triggered` signal:
-- `ShopPanel.setPrompt`'s measured seam, because *"a spec cannot fire a real ProximityPrompt"*.
function RangePanel.setPrompt(next_: any)
	if prompt == next_ then
		return
	end
	if promptConnection ~= nil then
		pcall(function()
			(promptConnection :: any):Disconnect()
		end)
		promptConnection = nil
	end
	for _, connection in ipairs(shownConnections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	shownConnections = {}
	promptShown = false
	prompt = next_
	if next_ == nil then
		return
	end
	-- WHICH DOOR ANSWERS: the service says when the engine is offering this prompt.
	pcall(function()
		table.insert(
			shownConnections,
			ProximityPromptService.PromptShown:Connect(function(shown)
				if shown == next_ then
					RangePanel.setPromptShown(true)
				end
			end)
		)
		table.insert(
			shownConnections,
			ProximityPromptService.PromptHidden:Connect(function(hidden)
				if hidden == next_ then
					RangePanel.setPromptShown(false)
				end
			end)
		)
	end)
	local ok, connection = pcall(function()
		return next_.Triggered:Connect(function()
			RangePanel.onPromptTriggered()
		end)
	end)
	if ok and connection ~= nil then
		promptConnection = connection
		stats.prompts += 1
	else
		prompt = nil
	end
end

function RangePanel.hasPrompt(): boolean
	return promptConnection ~= nil
end

-- THE WAY IN DOES NOT DEPEND ON WHERE SHE IS LOOKING (task 308 bug 2). MEASURED in Karen's place
-- on 46cbd787: 1.90 studs from the prompt, `Enabled=true`, `MaxActivationDistance=12`, turning the
-- camera off the post fired `ProximityPromptService.PromptHidden` and four real `E` presses then
-- produced `trig=0` -- the keys arrived (`InputBegan` counted 4, `gameProcessed=false`) and the
-- engine answered none, because a HIDDEN prompt does not answer its key and a prompt is hidden
-- whenever its own point is off screen. Walking up to the post and looking down the lane is that.
-- So the panel binds `E` itself while he is at the spot; the prompt stays as the thing he can SEE.
local function toggle()
	if not enabled then
		return
	end
	RangePanel.setOpen(not open)
end

-- WHETHER THE ENGINE IS SHOWING ITS PROMPT, as a parameter as well as a signal (CLAUDE.md's rule
-- for a two-state path). `setPrompt` wires `ProximityPromptService` to it.
function RangePanel.setPromptShown(on: boolean)
	promptShown = on == true
end

function RangePanel.isPromptShown(): boolean
	return promptShown
end

-- WHETHER A CLIMB PROMPT IS BEING OFFERED, as a parameter as well as a signal -- the two-arms rule,
-- so a spec reaches both states while the live world sits at one of them.
function RangePanel.setClimbShown(on: boolean)
	climbShown = on == true
end

function RangePanel.isClimbShown(): boolean
	return climbShown
end

-- DOES THAT CLIMB PROMPT TAKE **THIS PANEL'S** KEY? Only then may the panel stand down for it
-- (306k). The way UP is on `E` and the way DOWN is on `F`; the stand-down exists because the engine
-- is already answering `E`, and it answers nothing of the sort for `F`. MEASURED in her place: with
-- the down prompt finally DRAWN on the deck, a real `E` up there opened no menu at all -- the panel
-- swallowed it for a prompt on another key (frame 306k-deckmenu).
function RangePanel.climbTakesKey(instance: any): boolean
	if not RangePanel.isClimbPrompt(instance) then
		return false
	end
	local ok, key = pcall(function()
		return (instance :: any).KeyboardKeyCode
	end)
	return ok and key == RangePanel.KEY
end

-- IS THAT INSTANCE ONE OF THE RANGE'S CLIMB PROMPTS? By NAME, which is `Range.climbPromptName`'s own
-- rule -- nothing here knows where either one hangs.
function RangePanel.isClimbPrompt(instance: any): boolean
	if typeof(instance) ~= "Instance" then
		return false
	end
	local name = (instance :: Instance).Name
	for spot = 1, RangeData.LAYOUT.SPOT_COUNT do
		if name == RangeData.climbPromptName(spot, "up") or name == RangeData.climbPromptName(spot, "down") then
			return true
		end
	end
	return false
end

-- THE CLIMB PROMPTS' OWN WATCH, wired ONCE from the boot and not per station: the service says which
-- prompt the engine is offering, and this panel only has to know whether it is a climb.
function RangePanel.watchClimbPrompts()
	if #climbConnections > 0 then
		return
	end
	pcall(function()
		table.insert(
			climbConnections,
			ProximityPromptService.PromptShown:Connect(function(shown)
				if RangePanel.climbTakesKey(shown) then
					RangePanel.setClimbShown(true)
				end
			end)
		)
		table.insert(
			climbConnections,
			ProximityPromptService.PromptHidden:Connect(function(hidden)
				if RangePanel.climbTakesKey(hidden) then
					RangePanel.setClimbShown(false)
				end
			end)
		)
	end)
end

function RangePanel.onPromptTriggered()
	toggle()
end

-- ONE PRESS, ONE TOGGLE, AND THE SHOWN PROMPT HAS RIGHT OF WAY. MEASURED live on this build: while
-- the prompt is shown the engine's own handler consumes `E` before a non-core `BindAction` ever
-- runs, and it fires `Triggered` -- so the binding below is the door for exactly the case that was
-- broken, the HIDDEN prompt, and stands down when the engine is already answering.
function RangePanel.onKeyPressed()
	stats.keys += 1
	-- ...OR WHILE A CLIMB PROMPT IS SHOWN (step B10): that one is on `E` as well, and the engine is
	-- answering it. Without this, one press at the ladder's foot climbs AND opens the menu.
	if promptShown or climbShown then
		stats.swallowed += 1
		return
	end
	toggle()
end

-- `Pass`, NEVER `Sink`: the lobby's shop prompt is on `E` too, and swallowing the key would break
-- a door this module does not own.
local function onKey(_name: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		RangePanel.onKeyPressed()
	end
	return Enum.ContextActionResult.Pass
end

function RangePanel.bindKey(on: boolean)
	on = on == true
	if on == keyBound then
		return
	end
	keyBound = on
	pcall(function()
		if on then
			ContextActionService:BindAction(RangePanel.KEY_ACTION, onKey, false, RangePanel.KEY)
		else
			ContextActionService:UnbindAction(RangePanel.KEY_ACTION)
		end
	end)
end

function RangePanel.hasKey(): boolean
	return keyBound
end

-- THE SERVER'S LISTS AND ITS LIVE TRIAL (design 8.5). The panel holds no opinion about either.
function RangePanel.setState(next_: any)
	if type(next_) ~= "table" then
		return
	end
	state = next_
	RangePanel.render()
end

function RangePanel.lastState(): any
	return state
end

-- THE FLAG BY PARAMETER, because CLAUDE.md requires it: *"a flagged path must be reachable by
-- parameter as well as by flag"*.
function RangePanel.setEnabled(on: boolean)
	enabled = on == true
	if not enabled then
		RangePanel.setOpen(false)
	end
	-- SYMMETRIC, or an enabled false->true cycle at the post leaves E dead -- the same shape as
	-- the bug this task fixes (round 1, note).
	RangePanel.bindKey(enabled and near)
end

function RangePanel.isEnabled(): boolean
	return enabled
end

function RangePanel.start(root: Frame, collaborators: any)
	collaborators = collaborators or {}
	Cursor = collaborators.Cursor
	WeaponInput = collaborators.Input
	send = collaborators.send
	if send == nil and collaborators.remotes ~= nil then
		local remotes = collaborators.remotes
		send = function(request: any)
			pcall(function()
				remotes.RangeRequest:FireServer(request)
			end)
		end
	end
	picked = {}
	state = nil
	open = false
	near = false
	-- A FRESH START OWNS NOTHING: the key is bound by `setNear` when he arrives.
	RangePanel.bindKey(false)
	RangePanel.build(root)
	root.Visible = false
end

-- THE CLIMB WATCH'S OWN STAND-DOWN, and it is not tidiness: a climb prompt DESTROYED while it is
-- shown (`Range.stop` takes the whole folder) fires no `PromptHidden`, so `climbShown` would stay
-- true and `onKeyPressed` would swallow `E` for the rest of the session (round 1, note).
function RangePanel.unwatchClimbPrompts()
	for _, connection in ipairs(climbConnections) do
		pcall(function()
			(connection :: any):Disconnect()
		end)
	end
	climbConnections = {}
	climbShown = false
end

function RangePanel.stop()
	RangePanel.setOpen(false)
	RangePanel.bindKey(false)
	RangePanel.setPrompt(nil)
	RangePanel.unwatchClimbPrompts()
	panel = nil
	state = nil
	picked = {}
	buttons = {}
	confirmButton = nil
	leaveButton = nil
end

return RangePanel
