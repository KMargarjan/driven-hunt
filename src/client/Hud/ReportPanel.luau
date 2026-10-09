--!strict
-- Hud.ReportPanel: THE ONE WRITER of everything inside the `ReportPanel` frame, and the one binder of
-- the `DrivenHunt.Report.*` actions (CLAUDE.md rule 3).
--
-- Karen, 2026-10-05: *"we need to show on the end what has been killed where was the hit / so after
-- drive we can see how much I killed compairing others and I can click on details or similar and see
-- boars where was the hit / something simple but cool"*. That sentence is two screens, and this file is
-- both of them:
--
--   LIST    one row per hunter -- male / female / cub, kills, lost, points -- sorted by kills, which
--           is the "compairing others" half.
--   DETAIL  one row per animal of one hunter: a side-view boar with a DOT WHERE EACH SHOT LANDED,
--           coloured by zone, the fatal one marked, with the range in metres. The "where was the hit"
--           half.
--
-- IT DRAWS WHAT ARRIVED AND COMPUTES NOTHING. No count, no sort order, no placement: `HitLog.Shape`
-- does all of it on the server so two clients can never disagree about the order of the rows
-- (design section 7). The only arithmetic here is pixels from the fractions in the payload.
--
-- IT HOLDS FIVE PIECES OF STATE AND IS THE ONLY WRITER OF ALL FIVE: `open`, `view`, `selected`,
-- `page`, `autoOpenedFor`.
--
-- THE FRAME IS NOT ITS OWN. `Hud.build` creates `ReportPanel` with the rest of the screen, for the
-- reason the Hud's header already gives: one ScreenGui, built once, so a visibility audit has one
-- place to look. This module fills it and shows it.
--
-- Design: docs/design/drive-report.md (sections 4.3, 7, 8)
-- Note:   docs/research/2026-10-05-drive-report.md
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Drive = require(ReplicatedStorage:WaitForChild("Drive"))
local Report = require(ReplicatedStorage:WaitForChild("Report"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local CONFIG = Report.CONFIG

local ReportPanel = {}

-- The reserved prefix, the convention GAME_DESIGN.md's *Input* row sets out: a grep for
-- "DrivenHunt.Report." finds every binding this module owns and no other system may use it.
local TOGGLE = "DrivenHunt.Report.Toggle"
local BACK = "DrivenHunt.Report.Back"
local OPEN = "DrivenHunt.Report.Open"
local UP = "DrivenHunt.Report.Up"
local DOWN = "DrivenHunt.Report.Down"
local PAGE_LEFT = "DrivenHunt.Report.PageLeft"
local PAGE_RIGHT = "DrivenHunt.Report.PageRight"

-- ---------------------------------------------------------------- state (five values, one writer)
local open = false
local view = "list"
local selected: number? = nil
local page = 1
local autoOpenedFor: number? = nil

local started = false
local panel: Frame? = nil
local title: TextLabel? = nil
local header: TextLabel? = nil
local footer: TextLabel? = nil
local listRows: { TextButton } = {}
local detailRows: { Frame } = {}
local payload: any = nil

-- The collaborators, resolved once at `start` and all three optional -- the same shape `Hud.start`
-- uses for the camera and the match, and for the same reason: this panel works in a world that has
-- booted none of them, and draws what it can.
local ReportSystem: any = nil
local WeaponInput: any = nil
local Cursor: any = nil
local MatchSystem: any = nil

local stats = { opens = 0, closes = 0, asks = 0, renders = 0, autoOpens = 0 }

function ReportPanel.stats()
	return table.clone(stats)
end

function ReportPanel.isOpen(): boolean
	return open
end

function ReportPanel.view(): string
	return view
end

function ReportPanel.selected(): number?
	return selected
end

function ReportPanel.page(): number
	return page
end

function ReportPanel.frame(): Frame?
	return panel
end

function ReportPanel.titleText(): string
	return if title then title.Text else ""
end

function ReportPanel.headerText(): string
	return if header then header.Text else ""
end

function ReportPanel.footerText(): string
	return if footer then footer.Text else ""
end

-- What is actually on screen, row by row: the seam a client spec reads instead of guessing.
function ReportPanel.rowText(): { string }
	local out = {}
	if view == "detail" then
		for _, row in ipairs(detailRows) do
			if row.Visible then
				local label = row:FindFirstChild("Text")
				table.insert(out, if label and label:IsA("TextLabel") then label.Text else "")
			end
		end
		return out
	end
	for _, row in ipairs(listRows) do
		if row.Visible then
			table.insert(out, row.Text)
		end
	end
	return out
end

-- Every dot drawn on every silhouette, as (u, v, zone, fatal). The one check that "the hit is shown
-- where it landed" is a check and not a hope.
function ReportPanel.dots(): { { u: number, v: number, zone: string, fatal: boolean } }
	local out = {}
	for _, row in ipairs(detailRows) do
		if row.Visible then
			local art = row:FindFirstChild("Silhouette")
			for _, child in ipairs(if art then art:GetChildren() else {}) do
				if child:IsA("Frame") and child.Name == "Dot" then
					table.insert(out, {
						u = (child:GetAttribute("U") :: number?) or 0,
						v = (child:GetAttribute("V") :: number?) or 0,
						zone = (child:GetAttribute("Zone") :: string?) or "",
						fatal = (child:GetAttribute("Fatal") :: boolean?) == true,
					})
				end
			end
		end
	end
	return out
end

-- ---------------------------------------------------------------- the picture, built once

-- EVERY CHILD SITS ABOVE THE PANEL'S OWN ZINDEX, and the frame of 2026-10-05 is why: with the panel
-- opaque at ZIndex 10 and its labels at the default 1, the whole report came out as an EMPTY BLACK
-- RECTANGLE -- the text was being drawn BEHIND its own background. (It was also what made the panel
-- look see-through at 0.08: what showed through was the text, not the forest.)
--
-- `ScreenGui.ZIndexBehavior` is the Hud's, not this module's, and this works under either of its two
-- values: under `Global` the absolute numbers order the whole screen, and under `Sibling` each of
-- these still orders correctly among its own siblings.
--   https://create.roblox.com/docs/reference/engine/enums/ZIndexBehavior
local Z = CONFIG.PANEL_Z_INDEX

local function label(parent: Instance, name: string, size: number, position: UDim2, width: number): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.ZIndex = Z + 1
	-- THE SAME BLACK OUTLINE every other label in this Hud wears. Over a bright forest a thin Code
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

-- ONE SILHOUETTE: a side-view boar, from `Report.CONFIG.BOAR`, in the single fill `BOAR_FILL`.
-- Thirteen `Frame`s with a `UICorner` each and no art, no mesh and no `ViewportFrame` -- a 104-px
-- picture of a boar does not need a camera, and a `ViewportFrame` per row would be eight of them.
--
-- IT DREW `Report.CONFIG.SILHOUETTE` ITSELF UNTIL TASK 135 -- five tinted zone rectangles, which
-- task 124 round 3's own note called "a colour-coded bar, not a boar's outline". Those rectangles
-- are still the record every dot is placed against; they are no longer the picture.
local function buildSilhouette(parent: Frame): Frame
	local art = Instance.new("Frame")
	art.Name = "Silhouette"
	-- ITS OWN DARK BACKING, and the first frame is why: over a sunlit forest the zone rectangles were
	-- being read against leaves, and a picture of an animal that competes with a tree is not a
	-- picture of an animal.
	art.BackgroundColor3 = CONFIG.ART_BACKGROUND
	art.BackgroundTransparency = 0
	art.BorderSizePixel = 0
	art.ZIndex = Z + 2
	art.Position = UDim2.fromOffset(8, 6)
	art.Size = UDim2.fromOffset(CONFIG.SILHOUETTE_WIDTH, CONFIG.SILHOUETTE_HEIGHT)
	art.Parent = parent
	-- THE ANIMAL, IN ONE FILL (task 135). Until now this loop painted `Report.CONFIG.SILHOUETTE`
	-- itself -- the five zone rectangles, each in its own tint -- and task 124 round 3's own note
	-- said what that looked like: "a colour-coded bar, not a boar's outline". The rectangles are
	-- still the record every dot is placed against; they are no longer the picture.
	--
	-- ONE COLOUR, THIRTEEN PARTS, NO ART FILE. Every number is a SCALE of this frame, so the same
	-- thirteen parts draw the same animal at 104 x 56 in a row and at any size a larger view asks for.
	for _, piece in ipairs(CONFIG.BOAR) do
		local part = Instance.new("Frame")
		part.Name = piece.name
		part.BackgroundColor3 = CONFIG.BOAR_FILL
		part.BackgroundTransparency = 0
		part.BorderSizePixel = 0
		part.Position = UDim2.fromScale(piece.u0, piece.v0)
		part.Size = UDim2.fromScale(piece.u1 - piece.u0, piece.v1 - piece.v0)
		-- ONE ZINDEX FOR THE WHOLE ANIMAL: the parts are the same colour, so there is nothing for a
		-- stacking order to decide, and the dots sit above all of them at Z + 5.
		part.ZIndex = Z + 3
		-- THE CORNER IS A FRACTION OF THE PART'S OWN SHORTER SIDE, in SCALE, so a leg does not turn
		-- into a lozenge when the silhouette is drawn larger. `UICorner`'s Scale is relative to the
		-- shorter side already (https://create.roblox.com/docs/reference/engine/classes/UICorner).
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(piece.corner, 0)
		corner.Parent = part
		part.Parent = art
	end
	return art
end

local function build(frame: Frame)
	panel = frame
	local width = CONFIG.PANEL_WIDTH
	title = label(frame, "Title", Drive.CONFIG.SCORE_TITLE_SIZE, UDim2.fromOffset(16, 10), width - 32)
	header = label(frame, "Header", Drive.CONFIG.SCORE_TEXT_SIZE, UDim2.fromOffset(16, 44), width - 32)
	-- 0.4 was the score panel's, over the arena. On this panel's second frame the column names were
	-- the first thing that stopped being readable, so the header is only slightly dimmed.
	header.TextTransparency = 0.15

	-- THE LIST ROWS ARE BUTTONS, because Karen asked to *"click on details or similar"*. A click does
	-- what Enter does; the keyboard path exists for a client with no mouse freed (no camera, so no
	-- `Cursor`), which is why it is not a nicety.
	local top = 44 + CONFIG.HEADER_HEIGHT + 4
	table.clear(listRows)
	for index = 1, CONFIG.HUNTER_ROWS do
		local row = Instance.new("TextButton")
		row.Name = string.format("ListRow%d", index)
		row.AutoButtonColor = false
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Font = Enum.Font.Code
		row.TextSize = Drive.CONFIG.SCORE_TEXT_SIZE
		row.TextColor3 = Drive.CONFIG.TEXT_COLOR
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Position = UDim2.fromOffset(16, top + (index - 1) * CONFIG.LIST_ROW_HEIGHT)
		row.Size = UDim2.fromOffset(width - 32, CONFIG.LIST_ROW_HEIGHT)
		row.Text = ""
		row.Visible = false
		row.ZIndex = Z + 1
		row.Parent = frame
		row.Activated:Connect(function()
			ReportPanel.selectRow(index)
		end)
		table.insert(listRows, row)
	end

	table.clear(detailRows)
	for index = 1, CONFIG.ANIMALS_PER_PAGE do
		local row = Instance.new("Frame")
		row.Name = string.format("DetailRow%d", index)
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Position = UDim2.fromOffset(16, top + (index - 1) * CONFIG.DETAIL_ROW_HEIGHT)
		row.Size = UDim2.fromOffset(width - 32, CONFIG.DETAIL_ROW_HEIGHT)
		row.Visible = false
		row.ZIndex = Z + 1
		row.Parent = frame
		buildSilhouette(row)
		local text = label(
			row,
			"Text",
			Drive.CONFIG.SCORE_TEXT_SIZE,
			UDim2.fromOffset(CONFIG.DETAIL_TEXT_X, 22),
			width - 32 - CONFIG.DETAIL_TEXT_X
		)
		assert(text.Name == "Text", "the detail row's label is read back by name")
		table.insert(detailRows, row)
	end

	footer = label(
		frame,
		"Footer",
		Drive.CONFIG.SCORE_TEXT_SIZE,
		UDim2.fromOffset(16, CONFIG.PANEL_HEIGHT - CONFIG.FOOTER_HEIGHT - 10),
		width - 32
	);
	(footer :: TextLabel).TextTransparency = 0.25
end

-- ---------------------------------------------------------------- the text, pure and exported

-- Pure and exported for the reason `Hud.renderScore` and `Hud.killLineText` are: a drive is 300
-- seconds long in the Forest Test and 600 in the real one, so no harness run ever reaches a drive's
-- end, and a spec that cannot ask for the text cannot prove the panel says anything.
function ReportPanel.listHeaderText(): string
	return "#  NAME              MALE  FEM  CUB   KILLS  LOST  POINTS"
end

function ReportPanel.listRowText(rank: number, row: any, points: number?): string
	local kinds = (row and row.byKind) or {}
	return string.format(
		"%-2d %-16s %4d %4d %4d %7d %5d %7s",
		rank,
		string.sub(tostring(row and row.name or "?"), 1, 16),
		(kinds.male or 0) + (kinds.unknown or 0),
		kinds.female or 0,
		kinds.cub or 0,
		(row and row.kills) or 0,
		(row and row.lost) or 0,
		if points ~= nil then string.format("%d", points) else "-"
	)
end

function ReportPanel.detailHeaderText(): string
	return "ANIMAL   RESULT   ZONE     RANGE  GUN       HITS"
end

-- ONE ANIMAL'S LINE. `result` is the record's own word: "down" is a carcass, "wounded" is Karen's
-- *"wounded-lost"* -- an animal somebody hit that the drive never accounted for.
function ReportPanel.detailRowText(row: any): string
	local kind = string.upper(tostring((row and row.kind) or "boar"))
	local result = if (row and row.result) == "down" then "DOWN" else "LOST"
	-- ...AND WHICH GUN (task 140, design section 9). The WIRE carries the weapon's id and the SCREEN
	-- carries its word -- `Weapons.row(id).label` -- which is the same split `AMMO_LABEL` has. A
	-- record from before the rifle has no id and prints nothing rather than the word "nil", the rule
	-- `Hud.killLineText` already follows for `animalKind`.
	local gun = Weapons.row(row and row.weapon)
	-- AFTER THE DISTANCE, not after the hits (design section 9, the Reviewer's note round 2): the
	-- zone, the range and the gun are the three facts about the SHOT, and the hit count is a fact
	-- about the animal.
	return string.format(
		"%-8s %-8s %-8s %3d m %-9s %4d",
		kind,
		result,
		tostring((row and row.zone) or "-"),
		Report.metres(row and row.distance),
		if gun ~= nil then gun.label else "",
		(row and row.hits) or 0
	)
end

-- ---------------------------------------------------------------- drawing

-- THE RING COLOUR PER ZONE, built once from the list of zones this panel draws (task 135).
--
-- `Report.CONFIG.ZONES` is that list, and this is its reader: it lost its old one when the five
-- tinted rectangles stopped being the picture, and a list in a shared config that nothing reads is
-- the kind of lie `Penalty.expired`'s own comment warns about. It is also the right shape for the
-- job -- a string off the wire indexes one small table, built at load, rather than two.
local RING: { [string]: Color3 } = {}
for _, zone in ipairs(CONFIG.ZONES) do
	local rect = CONFIG.SILHOUETTE[zone]
	if rect ~= nil then
		-- ...LIFTED UNTIL IT CAN BE READ ON THE ANIMAL (task 137). `body`'s tint is 16 of 255 per
		-- channel from `BOAR_FILL`, so that ring was not a ring; see `Report.ringColor`.
		RING[zone] = Report.ringColor(rect.tint, CONFIG.BOAR_FILL)
	end
end

local function clearDots(art: Frame)
	for _, child in ipairs(art:GetChildren()) do
		if child:IsA("Frame") and child.Name == "Dot" then
			child:Destroy()
		end
	end
end

-- ONE DOT PER HIT, at the (u, v) the server measured in the animal's own frame at the moment of the
-- shot. The fatal one is the marker's own kill colour and a little larger; a dot on the FAR flank is
-- half transparent, so a report of a broadside shows which side the animal was hit from.
local function drawDots(art: Frame, row: any)
	clearDots(art)
	for _, dot in ipairs((row and row.dots) or {}) do
		local pip = Instance.new("Frame")
		pip.Name = "Dot"
		pip.AnchorPoint = Vector2.new(0.5, 0.5)
		local size = if dot.fatal then CONFIG.DOT_PIXELS + 3 else CONFIG.DOT_PIXELS
		-- INSET BY HALF A DOT, so a hit at u = 0 -- a nose-on shot, which the zone measurement of
		-- 2026-10-05 showed is the commonest kind there is -- is drawn ON the animal instead of
		-- hanging half outside it. The shift is at most 5 px of 104, under 5% of the body's length,
		-- and it is a drawing decision: the record itself is untouched and the attributes below
		-- still carry the true (u, v).
		local insetU = (size / 2) / CONFIG.SILHOUETTE_WIDTH
		local insetV = (size / 2) / CONFIG.SILHOUETTE_HEIGHT
		-- ...AND THEN ONTO THE ANIMAL, if the inset still leaves it in the air (task 138). The
		-- nudge is applied to the DRAWN position, because that is the space `Report.CONFIG.BOAR`'s
		-- parts are laid out in; the attributes below still carry the true `(u, v)`.
		local drawnU, drawnV = Report.ontoBoar(
			insetU + math.clamp(dot.u or 0, 0, 1) * (1 - 2 * insetU),
			insetV + math.clamp(dot.v or 0, 0, 1) * (1 - 2 * insetV)
		)
		pip.Position = UDim2.fromScale(drawnU, drawnV)
		pip.Size = UDim2.fromOffset(size, size)
		pip.BackgroundColor3 = if dot.fatal then Shotgun.CONFIG.HIT_MARK_KILL_COLOR else Color3.new(1, 1, 1)
		pip.BackgroundTransparency = if (dot.side or 1) < 0 then CONFIG.FAR_SIDE_TRANSPARENCY else 0
		pip.BorderSizePixel = 0
		pip.ZIndex = Z + 5
		-- AN OUTLINE IN THE ZONE'S OWN COLOUR (task 135). It was black, for a reason that has gone:
		-- a white dot was invisible on the pale chest rectangle and a red one on the red head
		-- rectangle, and the animal is now a single mid fill that both read against. So the ring
		-- carries the zone instead -- head, chest, rear, legs or body at a glance -- which is the
		-- one thing the old tinted rectangles told you that a plain silhouette does not. The tints
		-- are `Boar.CONFIG.ZONES`' own, mirrored into `Report.CONFIG.SILHOUETTE` and asserted
		-- against the source by `tests/server/report_silhouette.spec.luau`.
		local edge = Instance.new("UIStroke")
		edge.Thickness = CONFIG.RING_THICKNESS
		-- A zone this panel does not draw falls back to the trunk's own colour rather than erroring
		-- on a string that came off the wire.
		edge.Color = RING[tostring(dot.zone or "")] or RING.body or Color3.new(0, 0, 0)
		edge.Parent = pip
		pip.Rotation = if dot.fatal then 45 else 0 -- the fatal dot reads as an X at a glance
		-- ...WHICH ONLY WORKS IF THE OTHERS ARE ROUND (task 135). They were all squares, so the
		-- fatal one was a square turned 45 degrees among squares; a round hit beside a turned one
		-- reads as a different KIND of mark rather than the same mark at a different angle. The
		-- fatal marker itself is untouched -- same size, same kill colour, same turn.
		if not dot.fatal then
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(0.5, 0)
			round.Parent = pip
		end
		-- The numbers a spec reads, on the thing itself: no second table to drift from the picture.
		pip:SetAttribute("U", dot.u or 0)
		pip:SetAttribute("V", dot.v or 0)
		pip:SetAttribute("Zone", tostring(dot.zone or ""))
		pip:SetAttribute("Fatal", dot.fatal == true)
		pip.Parent = art
	end
end

-- POINTS COME FROM `Match`, JOINED ON userId, ON THE CLIENT (design section 8.1). The report's payload
-- has no points field: scoring is the match's and this panel does not own a second opinion about it.
local function pointsFor(userId: number): number?
	if MatchSystem == nil then
		return nil
	end
	local snapshot = MatchSystem.get()
	for _, row in ipairs((snapshot and snapshot.rows) or {}) do
		if row.userId == userId then
			return row.points or 0
		end
	end
	return nil
end

local function renderList(data: any)
	local rows = (data and data.rows) or {}
	(title :: TextLabel).Text = string.format(
		"DRIVE %d   REPORT%s",
		(data and data.drive) or 0,
		if data and data.closed then "   (ENDED)" else ""
	);
	(header :: TextLabel).Text = ReportPanel.listHeaderText();
	(header :: TextLabel).Position = UDim2.fromOffset(16, 44)
	for index, row in ipairs(listRows) do
		local entry = rows[index]
		row.Visible = entry ~= nil
		if entry ~= nil then
			row.Text = ReportPanel.listRowText(index, entry, pointsFor(entry.userId))
			local mine = entry.userId == ReportPanel.localUserId
			row.TextColor3 = if mine then Drive.CONFIG.SCORE_HIGHLIGHT_COLOR else Drive.CONFIG.TEXT_COLOR
			row.BackgroundTransparency = if selected == index then 0.75 else 1
			row.ZIndex = Z + 1
			row.BackgroundColor3 = Drive.CONFIG.TEXT_COLOR
		end
	end
	for _, row in ipairs(detailRows) do
		row.Visible = false
	end
	(footer :: TextLabel).Text = if #rows == 0
		then "NOBODY HAS HIT ANYTHING YET          [TAB] CLOSE"
		else string.format(
			"%d ANIMALS HIT THIS DRIVE   [ENTER] DETAILS   [TAB] CLOSE",
			(data and data.animals) or 0
		)
end

local function renderDetail(data: any)
	local rows = (data and data.rows) or {}
	(title :: TextLabel).Text = string.format(
		"%s   DRIVE %d   %d SHOWN",
		string.upper(tostring((data and data.name) or "?")),
		(data and data.drive) or 0,
		#rows
	);
	-- THE HEADER MOVES TO WHERE THE ROWS' TEXT STARTS. In the first frame it sat at x = 16, over the
	-- silhouettes, and not one column name was above its own column.
	(header :: TextLabel).Text = ReportPanel.detailHeaderText();
	(header :: TextLabel).Position = UDim2.fromOffset(CONFIG.DETAIL_TEXT_X, 44)
	for _, row in ipairs(listRows) do
		row.Visible = false
	end
	for index, row in ipairs(detailRows) do
		local entry = rows[index]
		row.Visible = entry ~= nil
		local art = row:FindFirstChild("Silhouette")
		local text = row:FindFirstChild("Text")
		if entry ~= nil and art and art:IsA("Frame") then
			drawDots(art, entry)
			if text and text:IsA("TextLabel") then
				text.Text = ReportPanel.detailRowText(entry)
			end
		elseif art and art:IsA("Frame") then
			clearDots(art)
		end
	end
	(footer :: TextLabel).Text = string.format(
		"PAGE %d/%d   [<] [>] PAGE   [BACKSPACE] BACK   [TAB] CLOSE",
		(data and data.page) or 1,
		math.max(1, (data and data.pages) or 1)
	)
end

-- PUBLIC, for the same stated reason `Hud.renderScore` is: no harness run ever reaches a drive's end,
-- so a spec that cannot hand the panel a payload cannot prove the panel is really on screen -- which
-- is the one check `docs/PROJECT_CONTEXT.md`'s "a visibility audit certified a blank screen twice"
-- demands.
function ReportPanel.render(data: any)
	if panel == nil then
		return
	end
	payload = data
	stats.renders += 1
	view = if type(data) == "table" and data.view == "detail" then "detail" else "list"
	if view == "detail" then
		renderDetail(data)
	else
		renderList(data)
	end
end

ReportPanel.localUserId = 0

-- ---------------------------------------------------------------- opening, closing, asking

local function ask(request)
	stats.asks += 1
	if ReportSystem ~= nil then
		ReportSystem.ask(request)
	end
end

function ReportPanel.setOpen(next_: boolean)
	if next_ == open then
		return
	end
	open = next_
	if panel ~= nil then
		panel.Visible = open
	end
	if open then
		stats.opens += 1
		-- THREE THINGS BESIDES DRAWING, and all three are requests to their owners rather than writes:
		-- free the mouse, hold the trigger, ask for the data.
		if Cursor ~= nil then
			Cursor.requestFree("report")
		end
		if WeaponInput ~= nil then
			WeaponInput.requestHold("report")
		end
		ask({ page = page })
	else
		stats.closes += 1
		if Cursor ~= nil then
			Cursor.release("report")
		end
		if WeaponInput ~= nil then
			WeaponInput.releaseHold("report")
		end
	end
end

function ReportPanel.toggle()
	ReportPanel.setOpen(not open)
end

-- A click on a row, or Enter on the highlighted one: list -> that hunter's detail.
function ReportPanel.selectRow(index: number)
	if not open then
		return
	end
	if view == "detail" then
		return
	end
	selected = index
	local rows = (payload and payload.rows) or {}
	local entry = rows[index]
	if entry == nil then
		-- Still redraw: the highlight moved even though there is nothing to open.
		ReportPanel.render(payload)
		return
	end
	page = 1
	ask({ drive = payload and payload.drive, hunter = entry.userId, page = 1 })
end

function ReportPanel.back()
	if not open then
		return
	end
	if view == "detail" then
		page = 1
		ask({ drive = payload and payload.drive, page = 1 })
	else
		ReportPanel.setOpen(false)
	end
end

function ReportPanel.move(delta: number)
	if not open or view ~= "list" then
		return
	end
	local count = #((payload and payload.rows) or {})
	if count == 0 then
		return
	end
	local next_ = ((selected or 1) - 1 + delta) % count + 1
	selected = next_
	ReportPanel.render(payload)
end

function ReportPanel.turnPage(delta: number)
	if not open or view ~= "detail" then
		return
	end
	page = math.max(1, page + delta)
	ask({ drive = payload and payload.drive, hunter = payload and payload.userId, page = page })
end

-- ---------------------------------------------------------------- input

-- EVERY HANDLER RETURNS `Pass`, like every other handler in this repo (`Weapon.Input`'s header says
-- why: sinking would swallow the Task 6 input probe, which is the harness's evidence that input
-- arrives at all).
local function on(fn: () -> ())
	return function(_name: string, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			fn()
		end
		return Enum.ContextActionResult.Pass
	end
end

local function bind()
	-- `Escape` IS NOT BOUND: it belongs to the Roblox menu and cannot be taken. Tab is this panel's,
	-- which is why `Hud.start` turns the stock player list off -- see its own comment there.
	ContextActionService:BindAction(TOGGLE, on(ReportPanel.toggle), false, CONFIG.TOGGLE_KEY)
	ContextActionService:BindAction(BACK, on(ReportPanel.back), false, Enum.KeyCode.Backspace)
	ContextActionService:BindAction(
		OPEN,
		on(function()
			ReportPanel.selectRow(selected or 1)
		end),
		false,
		Enum.KeyCode.Return
	)
	ContextActionService:BindAction(
		UP,
		on(function()
			ReportPanel.move(-1)
		end),
		false,
		Enum.KeyCode.Up
	)
	ContextActionService:BindAction(
		DOWN,
		on(function()
			ReportPanel.move(1)
		end),
		false,
		Enum.KeyCode.Down
	)
	ContextActionService:BindAction(
		PAGE_LEFT,
		on(function()
			ReportPanel.turnPage(-1)
		end),
		false,
		Enum.KeyCode.Left
	)
	ContextActionService:BindAction(
		PAGE_RIGHT,
		on(function()
			ReportPanel.turnPage(1)
		end),
		false,
		Enum.KeyCode.Right
	)
end

function ReportPanel.boundActions(): { string }
	local names = {}
	for _, name in ipairs({ TOGGLE, BACK, OPEN, UP, DOWN, PAGE_LEFT, PAGE_RIGHT }) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

-- ---------------------------------------------------------------- the drive boundary

-- A DRIVE CLOSES (design section 8.4): if the panel is already open it does NOT jump -- it re-asks for
-- the same view, so the numbers settle into their final values and a player reading a detail stays in
-- it. If it is closed it auto-opens ONCE, and `autoOpenedFor` is why "once" is a fact: Karen closing
-- it must leave it closed.
local function onDriveChanged(event: any)
	local kind = type(event) == "table" and event.kind or ""
	if kind == "driveClosed" then
		if open then
			if view == "detail" then
				ask({ drive = event.drive, hunter = payload and payload.userId, page = page })
			else
				ask({ drive = event.drive, page = 1 })
			end
		elseif autoOpenedFor ~= event.drive then
			autoOpenedFor = event.drive
			stats.autoOpens += 1
			view = "list"
			selected = nil
			page = 1
			ReportPanel.setOpen(true)
		end
	elseif kind == "driveOpened" then
		-- A panel over the first crossing is the modal mistake the research note names; the drive is
		-- starting, so the report gets out of the way.
		selected = nil
		page = 1
		ReportPanel.setOpen(false)
	end
end

ReportPanel.onDriveChanged = onDriveChanged

-- THE MATCH CAN ARRIVE AFTER THIS PANEL DOES (task 134). `PlayerScripts.Match` is replicated, so
-- the Hud cannot promise it exists when the panel is built -- and the points column is the only
-- thing here that reads it, so a panel built without one must be able to be given one rather than
-- going scoreless for the session. The Hud is the only caller; see `Hud.useMatch`.
function ReportPanel.setMatch(system: any)
	MatchSystem = system
end

function ReportPanel.start(frame: Frame, collaborators: any)
	if started then
		return
	end
	started = true
	ReportSystem = collaborators and collaborators.Report
	WeaponInput = collaborators and collaborators.Input
	Cursor = collaborators and collaborators.Cursor
	MatchSystem = collaborators and collaborators.Match
	ReportPanel.localUserId = (collaborators and collaborators.userId) or 0
	build(frame)
	frame.Visible = false
	bind()
	if ReportSystem ~= nil then
		ReportSystem.Data:Connect(function(data)
			-- DRAW ONLY WHAT WE ASKED FOR WHILE OPEN. A payload that arrives after a close is kept --
			-- so the next open has something to show -- but nothing is redrawn behind a hidden panel.
			payload = data
			if open then
				ReportPanel.render(data)
			end
		end)
		ReportSystem.DriveChanged:Connect(onDriveChanged)
	end
end

return ReportPanel
