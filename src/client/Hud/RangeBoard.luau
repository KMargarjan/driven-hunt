-- RangeBoard: the range's board. IT DRAWS WHAT IT IS SENT AND HOLDS NO OPINION -- the record is
-- `ServerScriptService.Range`'s and this is a renderer (design 9.3), the arrangement
-- `src/shared/Lobby/init.luau` states: *"the card lights the half the server says"*.
--
-- Design: docs/design/shooting-range.md section 9. Task 298 phase B, step B4.
--
-- Owner (CLAUDE.md rule 3): the one writer of its own Frame's children and of its own `Visible`.
-- It counts nothing. Every number on it arrived on `RangeBoard` (the remote), and the zone columns
-- are the ANIMAL's own order, sent with the record -- a boar has five, a red deer six.
--
-- TASK 304: IT IS A PAGE OF THE MENU NOW, NOT A PANEL OVER THE LANE. Karen, 2026-10-28, with the
-- board covering the left third of her view while she shot: *"if you remove this shit will be good
-- I will see where I hit"*. So it is visible EXACTLY while the E panel is open (`setMenuOpen`,
-- told by `Hud.step` the way `setNear` already is) and it is drawn inside the panel's own footprint,
-- below the hint -- `Hud` positions the frame off the SAME screen centre the panel is anchored to.
-- THIS MODULE STAYS THE WRITER and `RangePanel` gains nothing: the numbers, the columns and RESET
-- are already here, the record arrives here, and moving them would make two renderers of one record.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RangeData = require(ReplicatedStorage:WaitForChild("Range"))
local Report = require(ReplicatedStorage:WaitForChild("Report"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))

-- THE MENU'S OWN Z, read and not retyped: this board draws above it (see `LOOK.Z_INDEX`).
local RangePanel_Z = require(script.Parent.RangePanel).LOOK.Z_INDEX

local RangeBoard = {}

RangeBoard.LOOK = {
	PANEL = Color3.fromRGB(20, 22, 20),
	TEXT = Color3.fromRGB(232, 232, 224),
	LABEL = Color3.fromRGB(160, 164, 152),
	RESET = Color3.fromRGB(128, 72, 64),
	-- SIZED TO THE BAND THE MENU LEAVES FREE (task 304): the panel is 560 x 640, its hint ends at
	-- local y 438 and its bottom is 640, so 536 x 192 at local (12, 444) fits with 4 px to spare.
	WIDTH = 536,
	HEIGHT = 192,
	LINE_PITCH = 19,
	-- ABOVE THE MENU'S OWN CHILDREN. `ZIndexBehavior.Sibling` compares a child's ZIndex globally
	-- (`RangePanel.build`'s measured reason), and the menu draws at 14 with children at 15 and
	-- buttons at 16 -- so a board at 13 inside the panel's footprint would be invisible behind it.
	Z_INDEX = RangePanel_Z + 3,
}

local panel: Frame? = nil
local lines: { TextLabel } = {}
local resetButton: TextButton? = nil
local record: any = nil
local send: ((any) -> ())? = nil
-- WHETHER THE E PANEL IS OPEN (task 304). The board shows with it and hides with it: nothing of it
-- is on screen while she shoots.
local menuOpen = false
local stats = { pushes = 0, resets = 0, menuOpens = 0 }

function RangeBoard.panelSize(): UDim2
	return UDim2.fromOffset(RangeBoard.LOOK.WIDTH, RangeBoard.LOOK.HEIGHT)
end

function RangeBoard.isVisible(): boolean
	local root = panel
	return root ~= nil and root.Visible
end

function RangeBoard.stats()
	return table.clone(stats)
end

function RangeBoard.lastRecord(): any
	return record
end

-- EVERY COLUMN, AS ONE LINE EACH (design 9.1), and the two lead numbers each NAME WHO MEASURED IT:
-- the ballistic lead is `Ballistics.leadStuds`' answer and the view lead is the configured window,
-- so it is printed with a "<=" and never as a measurement.
function RangeBoard.rowText(): { string }
	local out = {}
	if type(record) ~= "table" then
		return { "no shots yet" }
	end
	table.insert(
		out,
		string.format("SHOTS %d   HITS %d   MISS %d", record.shots or 0, record.hits or 0, record.miss or 0)
	)
	local zones = {}
	local order = if type(record.zoneOrder) == "table" then record.zoneOrder else {}
	for _, zone in ipairs(order) do
		local count = if type(record.zones) == "table" then (record.zones[zone] or 0) else 0
		table.insert(zones, string.format("%s %d", string.upper(zone), count))
	end
	table.insert(zones, string.format("MISS %d", record.miss or 0))
	table.insert(out, table.concat(zones, "  "))
	table.insert(
		out,
		string.format(
			"DISTANCE %d studs (%d m)",
			math.floor((record.lastDistanceStuds or record.distanceStuds or 0) + 0.5),
			Report.metres(record.lastDistanceStuds or record.distanceStuds or 0)
		)
	)
	-- THE PACE'S OWN SPEED AND THE SPEED THE RUNTIME WAS ASKED FOR. They differ at STAND -- the
	-- target walks to the middle and then stands -- so both are printed and neither is guessed.
	table.insert(
		out,
		string.format(
			"PACE %s  pace %.1f studs/s  issued %.1f studs/s%s",
			string.upper(tostring(record.pace or "?")),
			record.paceStudsPerSecond or 0,
			record.issuedStudsPerSecond or 0,
			if record.crossingSeconds ~= nil then string.format("  crossing %.2f s", record.crossingSeconds) else ""
		)
	)
	table.insert(
		out,
		string.format(
			"LEAD BALLISTIC %.2f studs (%s)",
			record.leadBallisticStuds or 0,
			if (record.paceStudsPerSecond or 0) <= 0 then "0 -- the target stands" else "Ballistics.leadStuds"
		)
	)
	table.insert(
		out,
		string.format(
			"LEAD VIEW %s%.2f studs (%s)",
			if record.leadViewMeasured == true then "" else "<= ",
			record.leadViewStuds or 0,
			if record.leadViewMeasured == true then "measured lag" else "the configured window, a bound"
		)
	)
	-- THE SIGNED MISS GAP, IN METRES, IN KAREN'S WORDS (2026-10-27): *"0.9 m behind"*. Built by the
	-- server off `endPoint`; the words come from the repository's one stud-to-metre conversion.
	table.insert(out, "MISS GAP " .. (if record.lastGapText ~= nil then record.lastGapText else "--"))
	table.insert(
		out,
		string.format(
			"%s %s at %s",
			string.upper(tostring(record.species or "?")),
			tostring(record.kind or "?"),
			tostring(record.weapon or "?")
		)
			.. " / "
			.. RangeBoard.ammoText(record.weapon, record.ammo)
	)
	return out
end

-- THE CARTRIDGE AS THE GUN NAMES IT. `record.ammo` is the WIRE word -- "Slug" for BOTH guns,
-- because `Boar.Wound.damageFor` branches on that string -- so the board read "rifle / Slug" with
-- a .416 chosen and the ammo chip reading .416 (Director's proof, frame 14-walk). The row's own
-- `AMMO_LABEL` is the chip's source and `RangePanel`'s, so all three now say one thing.
function RangeBoard.ammoText(weapon: any, ammo: any): string
	local row = Weapons.row(weapon)
	local labels = if row ~= nil then row.AMMO_LABEL else nil
	if type(labels) == "table" and type(ammo) == "string" and type(labels[ammo]) == "string" then
		return labels[ammo]
	end
	return tostring(ammo or "?")
end

function RangeBoard.reset(): boolean
	local sender = send
	if sender == nil then
		return false
	end
	-- THROUGH THE SAME DOOR AS A PICK, whitelisted the same way: a reset is not a second remote, and
	-- the server clears THIS player's record only (Karen, 2026-10-27).
	sender({ spot = 1, reset = true })
	stats.resets += 1
	return true
end

-- EVERY CHILD CARRIES `Z_INDEX + 1` (the button `+ 2`), for `RangePanel.build`'s measured reason:
-- `ZIndexBehavior.Sibling` compares a child's ZIndex globally.
function RangeBoard.build(root: Frame)
	panel = root
	lines = {}
	for _, child in ipairs(root:GetChildren()) do
		child:Destroy()
	end

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 8)
	title.Size = UDim2.new(1, -24, 0, 20)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = RangeBoard.LOOK.TEXT
	title.ZIndex = RangeBoard.LOOK.Z_INDEX + 1
	title.Text = "THE BOARD"
	title.Parent = root

	for index = 1, 8 do
		local line = Instance.new("TextLabel")
		line.Name = "Line" .. tostring(index)
		line.BackgroundTransparency = 1
		line.Position = UDim2.fromOffset(12, 30 + (index - 1) * RangeBoard.LOOK.LINE_PITCH)
		line.Size = UDim2.new(1, -24, 0, RangeBoard.LOOK.LINE_PITCH - 1)
		-- GOTHAM, NOT `Enum.Font.Code`: the house style bans it on any surface of the HUD
		-- (`hud_style.spec`, task 201 part 1), which the first run of this spec caught.
		line.Font = Enum.Font.Gotham
		line.TextSize = 12
		line.TextWrapped = true
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.TextColor3 = RangeBoard.LOOK.LABEL
		line.ZIndex = RangeBoard.LOOK.Z_INDEX + 1
		line.Text = ""
		line.Parent = root
		table.insert(lines, line)
	end

	-- RESET ON THE TITLE ROW (task 304): the lines now fill the band the menu leaves, so the button
	-- sits beside the heading instead of under them.
	local reset = Instance.new("TextButton")
	reset.Name = "Reset"
	reset.AnchorPoint = Vector2.new(1, 0)
	reset.Position = UDim2.new(1, -12, 0, 6)
	reset.Size = UDim2.fromOffset(120, 22)
	reset.BackgroundColor3 = RangeBoard.LOOK.RESET
	reset.BorderSizePixel = 0
	reset.Font = Enum.Font.GothamBold
	reset.TextSize = 13
	reset.TextColor3 = RangeBoard.LOOK.TEXT
	reset.ZIndex = RangeBoard.LOOK.Z_INDEX + 2
	reset.Text = "RESET"
	reset.AutoButtonColor = true
	reset.Parent = root
	reset.Activated:Connect(function()
		RangeBoard.reset()
	end)
	resetButton = reset

	RangeBoard.render()
end

function RangeBoard.resetRect(): (Vector2?, Vector2?)
	local button = resetButton
	if button == nil then
		return nil, nil
	end
	return button.AbsolutePosition, button.AbsoluteSize
end

function RangeBoard.render()
	local root = panel
	if root == nil then
		return
	end
	local text = RangeBoard.rowText()
	for index, line in ipairs(lines) do
		line.Text = text[index] or ""
	end
	-- THE MENU DECIDES, AND NOTHING ELSE (task 304). Not the record: with the panel open and no shot
	-- fired `rowText` says "no shots yet", which is the honest page -- and with the panel shut there
	-- is nothing of this board on screen, which is Karen's sentence.
	root.Visible = menuOpen
end

-- THE E PANEL OPENED OR CLOSED (task 304), told by `Hud.step` -- the "a panel that is TOLD" idiom
-- `setNear` and `ShopPanel.setNear` already follow, so no module reaches into another's state.
function RangeBoard.setMenuOpen(next_: boolean)
	if menuOpen == next_ then
		return
	end
	menuOpen = next_
	if next_ then
		stats.menuOpens += 1
	end
	RangeBoard.render()
end

function RangeBoard.isMenuOpen(): boolean
	return menuOpen
end

-- HE WALKED OFF THE SPOT: the board goes with the menu (round 1, finding 3). The record is the
-- server's and this only drops the COPY -- the next push brings it back.
function RangeBoard.setNear(near: boolean)
	if near == true or record == nil then
		return
	end
	record = nil
	RangeBoard.render()
end

-- THE RECORD, TOLD to this module. It is the server's copy and this file never edits it.
function RangeBoard.setRecord(next_: any)
	record = next_
	stats.pushes += 1
	RangeBoard.render()
end

-- ONE PAYLOAD FROM `RangeBoard` (the remote): the record, and the lists the menu reads. The lists
-- go on to the panel through the composition root, not from here -- one reader per fact.
function RangeBoard.onBoard(payload: any): any
	if type(payload) ~= "table" then
		return nil
	end
	RangeBoard.setRecord(payload.record)
	return payload
end

function RangeBoard.start(root: Frame, collaborators: any)
	collaborators = collaborators or {}
	send = collaborators.send
	if send == nil and collaborators.remotes ~= nil then
		local remotes = collaborators.remotes
		send = function(request: any)
			pcall(function()
				remotes.RangeRequest:FireServer(request)
			end)
		end
	end
	record = nil
	menuOpen = false
	RangeBoard.build(root)
	root.Visible = false
	-- `RangeData` is required for the words only: the board prints no constant of its own.
	return RangeData.BOARD_REMOTE
end

function RangeBoard.stop()
	record = nil
	menuOpen = false
	lines = {}
	resetButton = nil
	panel = nil
end

return RangeBoard
