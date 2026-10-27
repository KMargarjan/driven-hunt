-- RangeBoard: the range's board. IT DRAWS WHAT IT IS SENT AND HOLDS NO OPINION -- the record is
-- `ServerScriptService.Range`'s and this is a renderer (design 9.3), the arrangement
-- `src/shared/Lobby/init.luau` states: *"the card lights the half the server says"*.
--
-- Design: docs/design/shooting-range.md section 9. Task 298 phase B, step B4.
--
-- Owner (CLAUDE.md rule 3): the one writer of its own Frame's children and of its own `Visible`.
-- It counts nothing. Every number on it arrived on `RangeBoard` (the remote), and the zone columns
-- are the ANIMAL's own order, sent with the record -- a boar has five, a red deer six.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RangeData = require(ReplicatedStorage:WaitForChild("Range"))
local Report = require(ReplicatedStorage:WaitForChild("Report"))

local RangeBoard = {}

RangeBoard.LOOK = {
	PANEL = Color3.fromRGB(20, 22, 20),
	TEXT = Color3.fromRGB(232, 232, 224),
	LABEL = Color3.fromRGB(160, 164, 152),
	RESET = Color3.fromRGB(128, 72, 64),
	WIDTH = 380,
	HEIGHT = 300,
	Z_INDEX = 13,
}

local panel: Frame? = nil
local lines: { TextLabel } = {}
local resetButton: TextButton? = nil
local record: any = nil
local send: ((any) -> ())? = nil
local stats = { pushes = 0, resets = 0 }

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
			.. tostring(record.ammo or "?")
	)
	return out
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
		line.Position = UDim2.fromOffset(12, 32 + (index - 1) * 24)
		line.Size = UDim2.new(1, -24, 0, 22)
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

	local reset = Instance.new("TextButton")
	reset.Name = "Reset"
	reset.AnchorPoint = Vector2.new(0.5, 1)
	reset.Position = UDim2.new(0.5, 0, 1, -10)
	reset.Size = UDim2.fromOffset(140, 30)
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
	root.Visible = record ~= nil
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
	RangeBoard.build(root)
	root.Visible = false
	-- `RangeData` is required for the words only: the board prints no constant of its own.
	return RangeData.BOARD_REMOTE
end

function RangeBoard.stop()
	record = nil
	lines = {}
	resetButton = nil
	panel = nil
end

return RangeBoard
