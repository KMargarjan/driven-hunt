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

local Report = require(ReplicatedStorage:WaitForChild("Report"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))

-- THE ONE BUILDER OF THE BOAR PICTURE AND THE ONE PLACER OF A DOT ON IT (task 198). It was three
-- local functions in this file until the hit card needed the same animal in the corner; moving them
-- was the alternative to a second drawing of a boar and a second way of placing a mark on it.
local BoarArt = require(script.Parent.BoarArt)
-- THE ONE SOURCE for every colour, face, size and component this panel draws with (task 201 part 2,
-- the Designer's design system, 2026-10-17). Surface 12: *"The same rebuild as the board, plus: the
-- footer's key hints become ghost chips instead of words inside a sentence; the selected row is
-- `ROW_HOVER` with a brass left bar; `DOWN` / `LOST` become tags; the silhouette dot art is
-- unchanged."* It is a MODAL (§3.1), so it lays a `SCRIM` over the whole screen at 0.42.
local Style = require(script.Parent.Style)

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

-- WHERE EVERY COLUMN OF BOTH TABLES SITS, inside the panel's padded body. One `TextLabel` per cell
-- (§3.12): the numbers line up because they are PLACED, which is what replaced the `%7d` padding
-- when `Enum.Font.Code` left.
--
-- THE TWO TABLES HAVE DIFFERENT COLUMNS and are two tables; what they share is the ROW, which is
-- `Style.tableRow` and is the component §3.12 asks for.
ReportPanel.LIST_COLUMNS = {
	{ key = "rank", head = "#", x = 0, w = 20, right = true },
	{ key = "name", head = "NAME", x = 28, w = 168, right = false },
	{ key = "male", head = "MALE", x = 200, w = 64, right = true },
	{ key = "female", head = "FEM", x = 270, w = 56, right = true },
	{ key = "cub", head = "CUB", x = 332, w = 56, right = true },
	{ key = "kills", head = "KILLS", x = 394, w = 64, right = true },
	{ key = "lost", head = "LOST", x = 464, w = 56, right = true },
	{ key = "points", head = "POINTS", x = 526, w = 72, right = true },
}

-- THE ANIMAL ROWS. `result` is a TAG and not a word in a column (§3.7), so its slot is a box and
-- the rest of the row is placed around it.
ReportPanel.DETAIL_COLUMNS = {
	{ key = "kind", head = "ANIMAL", x = 0, w = 70, right = false },
	{ key = "result", head = "RESULT", x = 76, w = 84, right = false },
	{ key = "zone", head = "ZONE", x = 168, w = 120, right = false },
	{ key = "range", head = "RANGE", x = 330, w = 90, right = true },
	{ key = "gun", head = "GUN", x = 428, w = 120, right = true },
	{ key = "hits", head = "HITS", x = 556, w = 42, right = true },
}

-- ---------------------------------------------------------------- state (five values, one writer)
local open = false
local view = "list"
local selected: number? = nil
local page = 1
local autoOpenedFor: number? = nil

local started = false
local panel: Frame? = nil
-- THE FULL-SCREEN SCRIM BEHIND THIS PANEL (§1.3). The Hud creates it; this module writes its
-- `Visible` with the panel's own, because they are one answer to one question.
local scrim: Frame? = nil
local title: TextLabel? = nil
local footer: TextLabel? = nil
local listRows: { TextButton } = {}
local detailRows: { Frame } = {}
-- ONE `TextLabel` PER CELL (§3.12), kept by column key so a renderer writes `cells.points` rather
-- than counting children. The two tables have different columns and so two lists.
local listCells: { { [string]: TextLabel } } = {}
local detailCells: { { [string]: TextLabel } } = {}
local listHead: Frame? = nil
local detailHead: Frame? = nil
-- The panel's own padding, and the bands its header and footer own.
local PAD = 16
local HEAD_H = 76
local FOOT_H = 52
-- Each animal row's result TAG, by row, because a tag is a Frame and its word is inside it.
ReportPanel.tagTextOf = {} :: { [Frame]: TextLabel }
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

-- WHAT THE PANEL'S EYEBROW SAYS, unspaced (§1.2 letter-spaces an uppercase label at 10 px, which
-- is tracking and not content).
function ReportPanel.eyebrowText(): string
	local label = ReportPanel.eyebrow
	return if label then (string.gsub((label :: TextLabel).Text, " ", "")) else ""
end

-- WHAT THE COLUMN HEAD OF THE VISIBLE TABLE SAYS, read off the drawn cells. It was one padded
-- `TextLabel` until task 201 part 2 and is one cell per column now, so this joins them in column
-- order -- and it answers the VISIBLE table, because the panel shows one of the two at a time.
function ReportPanel.headerText(): string
	local row = if view == "detail" then detailHead else listHead
	local columns = if view == "detail" then ReportPanel.DETAIL_COLUMNS else ReportPanel.LIST_COLUMNS
	if row == nil then
		return ""
	end
	local parts = {}
	for _, column in ipairs(columns) do
		local cell = (row :: Frame):FindFirstChild(column.key)
		if cell ~= nil then
			table.insert(parts, (string.gsub((cell :: TextLabel).Text, " ", "")))
		end
	end
	return table.concat(parts, " ")
end

function ReportPanel.footerText(): string
	return if footer then footer.Text else ""
end

-- What is actually on screen, row by row: the seam a client spec reads instead of guessing.
-- WHAT THE VISIBLE TABLE SAYS, ROW BY ROW, as plain words -- the DRAWN cells joined in column
-- order. It reads the labels and not the renderer's input, which is the whole point of it: the
-- tables are one `TextLabel` per cell now (§3.12), and a reader that asked the formatter instead
-- would be asserting the thing it is trying to check.
--
-- An animal's RESULT is a tag rather than a cell, so its word is read out of the tag.
function ReportPanel.rowText(): { string }
	local out = {}
	local rows = if view == "detail" then detailRows else listRows
	local cellsOf = if view == "detail" then detailCells else listCells
	local columns = if view == "detail" then ReportPanel.DETAIL_COLUMNS else ReportPanel.LIST_COLUMNS
	for index, node in ipairs(rows) do
		if not node.Visible then
			continue
		end
		local row = if view == "detail" then node :: Frame else (node :: Instance):FindFirstChild("Row") :: Frame
		local cells = cellsOf[index] or {}
		local parts = {}
		for _, column in ipairs(columns) do
			if column.key == "result" then
				local word = if row ~= nil then ReportPanel.tagTextOf[row] else nil
				if word ~= nil and word.Text ~= "" then
					table.insert(parts, (string.gsub(word.Text, " ", "")))
				end
				continue
			end
			local cell = cells[column.key]
			if cell ~= nil and cell.Text ~= "" then
				table.insert(parts, cell.Text)
			end
		end
		table.insert(out, table.concat(parts, " "))
	end
	return out
end

-- Every dot drawn on every silhouette, as (u, v, zone, fatal). The one check that "the hit is shown
-- where it landed" is a check and not a hope.
function ReportPanel.dots(): { { u: number, v: number, zone: string, fatal: boolean } }
	local out = {}
	for _, row in ipairs(detailRows) do
		if row.Visible then
			for _, dot in ipairs(BoarArt.dotsOf(row:FindFirstChild("Silhouette"))) do
				table.insert(out, dot)
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

-- ONE SILHOUETTE, from `Hud.BoarArt` (task 198): the report's own fill on the report's own dark
-- backing, nose-LEFT, at 104 x 56 -- the same picture, out of the file that is now its one builder.
local function buildSilhouette(parent: Frame): Frame
	return BoarArt.build(parent, "Silhouette", UDim2.fromOffset(0, 6), {
		fill = CONFIG.BOAR_FILL,
		backing = CONFIG.ART_BACKGROUND,
		width = CONFIG.SILHOUETTE_WIDTH,
		height = CONFIG.SILHOUETTE_HEIGHT,
		zIndex = Z + 2,
	})
end

-- HOW BIG THE PANEL IS -- the shop's own rule, which every modal in the game shares so a player
-- learns ONE panel shape (§3.1). 1280 x 720 gives 640 x 576; a 400 px phone gives 376 x 640.
function ReportPanel.panelSize(viewport: Vector2?): UDim2
	local camera = workspace.CurrentCamera
	local size = viewport
		or (
			if camera and camera.ViewportSize.X >= Style.MIN_SENSIBLE_PX
				then camera.ViewportSize
				else Vector2.new(1280, 720)
		)
	local margin = 12
	local width = math.clamp(size.X - 2 * margin, 300, 640)
	local height = math.clamp(math.floor(size.Y * 0.80), 300, 640)
	return UDim2.fromOffset(width, height)
end

function ReportPanel.bodyWidth(viewport: Vector2?): number
	return ReportPanel.panelSize(viewport).X.Offset - 2 * PAD
end

-- THE WHOLE PANEL, built once. It is a MODAL now (§3.1): an opaque lodge panel with a brass
-- hairline over a full-screen `SCRIM` at 0.42, an eyebrow + title pair, a well holding the table,
-- and a footer of GHOST KEY CHIPS instead of key names buried in a sentence.
local function build(frame: Frame)
	panel = frame
	-- `Style.viewportX` AND NOT `CurrentCamera.ViewportSize.X`: the camera reports (1, 1) until the
	-- engine has drawn a frame and `build` runs before that, so the ungated reader this line used to
	-- be built 24 px PHONE rows on a 969 px screen (caught by `hud_style.spec`, round 0 of part 2).
	local viewX = Style.viewportX()
	local size = ReportPanel.panelSize()
	frame.Size = size
	frame.BackgroundColor3 = Style.LOOK.PANEL
	frame.BackgroundTransparency = Style.PANEL_T
	Style.corner(frame, Style.RADIUS.MODAL)
	Style.stroke(frame, Style.LOOK.BRASS, Style.EDGE_T.PANEL)
	local width = size.X.Offset
	local body = width - 2 * PAD

	local headerFrame, eyebrow, titleLabel = Style.header(frame, body, viewX, false)
	headerFrame.Position = UDim2.fromOffset(PAD, 8)
	title = titleLabel
	ReportPanel.eyebrow = eyebrow

	-- THE ONE ICON BUTTON (§3.5), and the X is two rotated Frames so no glyph has to exist in the
	-- font -- the shop's own rule. `Escape` IS NOT BINDABLE (it belongs to the Roblox menu), so a
	-- panel that claimed to close on it would be lying; this and `Tab` are the two ways out.
	local close = Style.closeButton(frame, "Close")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -PAD, 0, 14)
	close.Activated:Connect(function()
		ReportPanel.setOpen(false)
	end)

	-- THE TABLE SITS IN A WELL sunk into the panel (§1.3's ladder: one step lighter and one step
	-- less round than the panel it is in).
	local well = Instance.new("Frame")
	well.Name = "Well"
	well.BackgroundColor3 = Style.LOOK.COLUMN
	well.BorderSizePixel = 0
	well.Position = UDim2.fromOffset(PAD, HEAD_H)
	well.Size = UDim2.fromOffset(body, size.Y.Offset - HEAD_H - FOOT_H - 8)
	well.ClipsDescendants = true
	well.ZIndex = Z + 1
	well.Parent = frame
	Style.corner(well, Style.RADIUS.WELL)
	Style.stroke(well, Style.LOOK.WELL_EDGE, Style.EDGE_T.WELL)
	Style.padding(well, 10, 10, 12, 12)
	ReportPanel.well = well
	local inner = body - 24

	-- THE COLUMN HEAD, its own row with the brass hairline under it, one per table.
	local function headRow(name: string, columns): Frame
		local row = Style.columnHead(well, name, viewX, inner, false)
		row.Position = UDim2.fromOffset(0, 0)
		for _, column in ipairs(columns) do
			local cell = Style.cell(row, column.key, viewX, column.x, column.w, column.right, "MICRO")
			cell.TextColor3 = Style.LOOK.FAINT
			cell.Text = Style.spaced(column.head)
		end
		return row
	end
	listHead = headRow("ListHead", ReportPanel.LIST_COLUMNS)
	detailHead = headRow("DetailHead", ReportPanel.DETAIL_COLUMNS)

	local rowH = Style.rowHeight(viewX)
	local top = rowH

	-- THE LIST ROWS ARE BUTTONS, because Karen asked to *"click on details or similar"*. A click
	-- does what Enter does; the keyboard path exists for a client with no mouse freed (no camera, so
	-- no `Cursor`), which is why it is not a nicety. The ROW inside each one is `Style.tableRow`,
	-- so the board and this panel draw the same row.
	table.clear(listRows)
	table.clear(listCells)
	for index = 1, CONFIG.HUNTER_ROWS do
		local button = Instance.new("TextButton")
		button.Name = string.format("ListRow%d", index)
		button.AutoButtonColor = false
		button.Text = ""
		button.BackgroundTransparency = 1
		button.BorderSizePixel = 0
		button.Position = UDim2.fromOffset(0, top + (index - 1) * rowH)
		button.Size = UDim2.fromOffset(inner, rowH)
		button.Visible = false
		button.ZIndex = Z + 1
		button.Parent = well
		local row = Style.tableRow(button, "Row", viewX, inner)
		row.Position = UDim2.fromOffset(0, 0)
		row.Visible = true
		local cells: { [string]: TextLabel } = {}
		for _, column in ipairs(ReportPanel.LIST_COLUMNS) do
			cells[column.key] = Style.cell(row, column.key, viewX, column.x, column.w, column.right)
		end
		button.Activated:Connect(function()
			ReportPanel.selectRow(index)
		end)
		table.insert(listRows, button)
		table.insert(listCells, cells)
	end

	-- THE ANIMAL ROWS: the silhouette, the cells, and the result as a TAG (§3.7) -- `DOWN` in pine,
	-- `WOUNDED` in clay. A STATE IS NEVER COLOUR ALONE, which is why the tag carries the word.
	table.clear(detailRows)
	table.clear(detailCells)
	for index = 1, CONFIG.ANIMALS_PER_PAGE do
		local row = Style.tableRow(well, string.format("DetailRow%d", index), viewX, inner)
		row.Size = UDim2.fromOffset(inner, CONFIG.DETAIL_ROW_HEIGHT)
		row.Position = UDim2.fromOffset(0, top + (index - 1) * CONFIG.DETAIL_ROW_HEIGHT)
		buildSilhouette(row)
		local cells: { [string]: TextLabel } = {}
		for _, column in ipairs(ReportPanel.DETAIL_COLUMNS) do
			if column.key == "result" then
				continue
			end
			local cell = Style.cell(row, column.key, viewX, column.x, column.w, column.right)
			cell.Position = UDim2.fromOffset(column.x, 0)
			cells[column.key] = cell
		end
		local tag, tagText = Style.tag(row, "Result", Style.LOOK.PINE_TEXT, viewX)
		tag.AnchorPoint = Vector2.new(0, 0.5)
		tag.Position = UDim2.new(0, ReportPanel.DETAIL_COLUMNS[2].x, 0.5, 0)
		tag.Visible = false
		ReportPanel.tagTextOf[row] = tagText
		table.insert(detailRows, row)
		table.insert(detailCells, cells)
	end

	-- THE FOOTER: the sentence on the left, and the KEY HINTS as ghost chips on the right (§5
	-- surface 12). They were `[ENTER] DETAILS   [TAB] CLOSE` inside the sentence itself.
	local foot = Instance.new("Frame")
	foot.Name = "Footer"
	foot.BackgroundTransparency = 1
	foot.BorderSizePixel = 0
	foot.AnchorPoint = Vector2.new(0, 1)
	foot.Position = UDim2.new(0, PAD, 1, -14)
	foot.Size = UDim2.fromOffset(body, 30)
	foot.ZIndex = Z + 1
	foot.Parent = frame

	footer = Style.label(foot, "Text", "BODY", viewX);
	(footer :: TextLabel).TextColor3 = Style.LOOK.MUTED;
	(footer :: TextLabel).Size = UDim2.new(1, -260, 1, 0);
	(footer :: TextLabel).TextXAlignment = Enum.TextXAlignment.Left

	local chips = Instance.new("Frame")
	chips.Name = "Keys"
	chips.BackgroundTransparency = 1
	chips.AutomaticSize = Enum.AutomaticSize.X
	chips.AnchorPoint = Vector2.new(1, 0.5)
	chips.Position = UDim2.fromScale(1, 0.5)
	chips.Size = UDim2.fromScale(0, 1)
	chips.ZIndex = foot.ZIndex
	chips.Parent = foot
	local chipRow = Instance.new("UIListLayout")
	chipRow.FillDirection = Enum.FillDirection.Horizontal
	chipRow.VerticalAlignment = Enum.VerticalAlignment.Center
	chipRow.SortOrder = Enum.SortOrder.LayoutOrder
	chipRow.Padding = UDim.new(0, 8)
	chipRow.Parent = chips
	ReportPanel.keyChips = {
		enter = Style.keyChip(chips, "Enter", "ENTER", "DETAILS", viewX),
		back = Style.keyChip(chips, "Back", "BACKSPACE", "BACK", viewX),
		page = Style.keyChip(chips, "Page", "< >", "PAGE", viewX),
		close = Style.keyChip(chips, "Close", "TAB", "CLOSE", viewX),
	}
	ReportPanel.keyChips.enter.LayoutOrder = 1
	ReportPanel.keyChips.back.LayoutOrder = 2
	ReportPanel.keyChips.page.LayoutOrder = 3
	ReportPanel.keyChips.close.LayoutOrder = 4
end

-- ---------------------------------------------------------------- the text, pure and exported

-- Pure and exported for the reason `Hud.renderScore` and `Hud.killLineText` are: a drive is 300
-- seconds long in the Forest Test and 600 in the real one, so no harness run ever reaches a drive's
-- end, and a spec that cannot ask for the text cannot prove the panel says anything.
-- WHAT ONE COLUMN HEAD ROW SAYS, joined. The columns themselves are `ReportPanel.LIST_COLUMNS` /
-- `DETAIL_COLUMNS`, which is where the x and the width live; this is the WORDS, for a reader.
local function headText(columns): string
	local parts = {}
	for _, column in ipairs(columns) do
		table.insert(parts, column.head)
	end
	return table.concat(parts, " ")
end

function ReportPanel.listHeaderText(): string
	return headText(ReportPanel.LIST_COLUMNS)
end

function ReportPanel.detailHeaderText(): string
	return headText(ReportPanel.DETAIL_COLUMNS)
end

-- ONE PLAYER'S ROW, AS CELLS (§3.12: *"one `TextLabel` per cell"*). THE PADDING IS GONE with
-- `Enum.Font.Code` -- *"the numbers line up because they are PLACED, not because every glyph is one
-- width"* (§1.2) -- so this answers the WORDS and `LIST_COLUMNS` answers where each goes.
function ReportPanel.listCellsFor(rank: number, row: any, points: number?): { [string]: string }
	local kinds = (row and row.byKind) or {}
	return {
		rank = tostring(rank),
		name = string.sub(tostring(row and row.name or "?"), 1, 18),
		male = tostring((kinds.male or 0) + (kinds.unknown or 0)),
		female = tostring(kinds.female or 0),
		cub = tostring(kinds.cub or 0),
		kills = tostring((row and row.kills) or 0),
		lost = tostring((row and row.lost) or 0),
		-- AN UNKNOWN IS NOT DRAWN AT ALL rather than `-` (§3.12): points come from `Match`, joined
		-- on userId, and a client that has not got the snapshot yet does not know them.
		points = if points ~= nil then string.format("%d", points) else "",
	}
end

-- ONE ANIMAL'S ROW, AS CELLS. `result` is the record's own word: "down" is a carcass, "wounded" is
-- Karen's *"wounded-lost"* -- an animal somebody hit that the drive never accounted for. It is
-- drawn as a TAG (§3.7) and so is the one cell that carries a MEANING as well as a word.
function ReportPanel.detailCellsFor(row: any): { [string]: string }
	-- ...AND WHICH GUN (task 140, design section 9). The WIRE carries the weapon's id and the SCREEN
	-- carries its word -- `Weapons.row(id).label` -- the same split `AMMO_LABEL` has. A record from
	-- before the rifle has no id and prints nothing rather than the word "nil".
	local gun = Weapons.row(row and row.weapon)
	return {
		kind = string.upper(tostring((row and row.kind) or "boar")),
		-- THE SCREEN'S WORD AND NOT THE WIRE'S. The record says "down" / "wounded"; the board used
		-- to print `LOST` and the mockup (board 4) says `WOUNDED`, which is Karen's own
		-- *"wounded-lost"* -- an animal somebody hit that the drive never accounted for. ONE word,
		-- here, so the tag and the line cannot say two different things.
		result = if (row and row.result) == "down" then "DOWN" else "WOUNDED",
		zone = tostring((row and row.zone) or "-"),
		range = string.format("%d m", Report.metres(row and row.distance)),
		gun = if gun ~= nil then gun.label else "",
		hits = tostring((row and row.hits) or 0),
	}
end

-- ...AND THE SAME ROWS AS ONE LINE EACH. Kept for the reason `Hud.scoreRowText`'s own line is kept:
-- a spec that wants the row's FACTS rather than its pixels reads this, and the tie between the two
-- is ONE function rather than two formatters that can disagree.
local function joined(columns, cells): string
	local parts = {}
	for _, column in ipairs(columns) do
		local word = cells[column.key]
		if word ~= nil and word ~= "" then
			table.insert(parts, word)
		end
	end
	return table.concat(parts, " ")
end

function ReportPanel.listRowText(rank: number, row: any, points: number?): string
	return joined(ReportPanel.LIST_COLUMNS, ReportPanel.listCellsFor(rank, row, points))
end

function ReportPanel.detailRowText(row: any): string
	return joined(ReportPanel.DETAIL_COLUMNS, ReportPanel.detailCellsFor(row))
end

-- ---------------------------------------------------------------- drawing

local function clearDots(art: Frame)
	BoarArt.clearDots(art)
end

-- ONE DOT PER HIT, drawn by `Hud.BoarArt` -- the report's scheme: a white dot ringed in the zone's
-- own lifted colour, the fatal one turned 45 degrees in the kill marker's red, and a dot on the FAR
-- flank half transparent so a report of a broadside shows which side the animal was hit from.
local function drawDots(art: Frame, row: any)
	BoarArt.drawDots(art, (row and row.dots) or {}, {
		fill = CONFIG.BOAR_FILL,
		width = CONFIG.SILHOUETTE_WIDTH,
		height = CONFIG.SILHOUETTE_HEIGHT,
		zIndex = Z + 3,
		fadeFarSide = true,
	})
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

-- WHICH KEY CHIPS THE FOOTER SHOWS. PURE: the list offers DETAILS and CLOSE, the detail view offers
-- PAGE, BACK and CLOSE. A chip for a key that does nothing in this view is the "no dead buttons"
-- rule applied to a legend.
function ReportPanel.keysFor(whichView: string): { string }
	if whichView == "detail" then
		return { "page", "back", "close" }
	end
	return { "enter", "close" }
end

local function applyKeys(whichView: string)
	local wanted = {}
	for _, key in ipairs(ReportPanel.keysFor(whichView)) do
		wanted[key] = true
	end
	for key, chip in pairs(ReportPanel.keyChips or {}) do
		(chip :: Frame).Visible = wanted[key] == true
	end
end

local function renderList(data: any)
	local rows = (data and data.rows) or {}
	(ReportPanel.eyebrow :: TextLabel).Text = Style.spaced(if data and data.closed then "DRIVE ENDED" else "THIS DRIVE");
	(title :: TextLabel).Text = string.format("DRIVE %d REPORT", (data and data.drive) or 0)
	if listHead ~= nil then
		(listHead :: Frame).Visible = true
	end
	if detailHead ~= nil then
		(detailHead :: Frame).Visible = false
	end
	for index, button in ipairs(listRows) do
		local entry = rows[index]
		button.Visible = entry ~= nil
		if entry == nil then
			continue
		end
		local row = button:FindFirstChild("Row") :: Frame
		local cells = listCells[index]
		local mine = entry.userId == ReportPanel.localUserId
		-- THE SELECTED ROW IS `ROW_HOVER` WITH A BRASS LEFT BAR (§5 surface 12), and YOUR row is
		-- `ROW_SELECTED` with your team's. `Style.rowState` is the one writer of both.
		Style.rowState(row, mine, entry.team, selected == index)
		local bar = row:FindFirstChild("Bar")
		if bar ~= nil and selected == index and not mine then
			(bar :: Frame).Visible = true
			(bar :: Frame).BackgroundColor3 = Style.LOOK.BRASS
		end
		local words = ReportPanel.listCellsFor(index, entry, pointsFor(entry.userId))
		for key, cell in pairs(cells) do
			local word = words[key] or ""
			cell.Text = word
			cell.TextColor3 = ReportPanel.cellColor(key, word, mine)
		end
		-- The last drawn row wears no rule (§3.12).
		local rule = row:FindFirstChild("Rule")
		if rule ~= nil then
			(rule :: Frame).Visible = rows[index + 1] ~= nil
		end
	end
	for _, row in ipairs(detailRows) do
		row.Visible = false
	end
	(footer :: TextLabel).Text = if #rows == 0
		then "Nobody has hit anything yet"
		else string.format("%d animals hit this drive", (data and data.animals) or 0)
	applyKeys("list")
end

local function renderDetail(data: any)
	local rows = (data and data.rows) or {}
	-- THE EYEBROW IS WHOSE REPORT THIS IS AND HOW MANY ANIMALS -- the mockup's `KAREN - 3 ANIMALS`
	-- (board 4) -- and the title stays the drive's, so the player never loses which screen he is on.
	(ReportPanel.eyebrow :: TextLabel).Text =
		Style.spaced(string.format("%s - %d ANIMALS", string.upper(tostring((data and data.name) or "?")), #rows));
	(title :: TextLabel).Text = string.format("DRIVE %d REPORT", (data and data.drive) or 0)
	if listHead ~= nil then
		(listHead :: Frame).Visible = false
	end
	if detailHead ~= nil then
		(detailHead :: Frame).Visible = true
	end
	for _, button in ipairs(listRows) do
		button.Visible = false
	end
	for index, row in ipairs(detailRows) do
		local entry = rows[index]
		row.Visible = entry ~= nil
		local art = row:FindFirstChild("Silhouette")
		local cells = detailCells[index]
		local tag = row:FindFirstChild("Result")
		if entry == nil then
			if art and art:IsA("Frame") then
				clearDots(art)
			end
			continue
		end
		if art and art:IsA("Frame") then
			drawDots(art, entry)
		end
		local words = ReportPanel.detailCellsFor(entry)
		for key, cell in pairs(cells) do
			cell.Text = words[key] or ""
			cell.TextColor3 = ReportPanel.cellColor(key, cell.Text, false)
		end
		-- `DOWN` IN PINE, `WOUNDED` IN CLAY (§3.7), and the word is always there: a state is never
		-- colour alone. The wire's own word is "LOST"; the screen's is Karen's, "WOUNDED".
		if tag ~= nil then
			local down = words.result == "DOWN"
			local tint = if down then Style.LOOK.PINE_TEXT else Style.LOOK.CLAY;
			(tag :: Frame).Visible = true
			(tag :: Frame).BackgroundColor3 = tint
			local edge = (tag :: Frame):FindFirstChildOfClass("UIStroke")
			if edge ~= nil then
				edge.Color = tint
			end
			local word = ReportPanel.tagTextOf[row]
			if word ~= nil then
				word.Text = Style.spaced(words.result)
				word.TextColor3 = tint
			end
		end
		local rule = row:FindFirstChild("Rule")
		if rule ~= nil then
			(rule :: Frame).Visible = rows[index + 1] ~= nil
		end
	end
	(footer :: TextLabel).Text =
		string.format("Page %d of %d", (data and data.page) or 1, math.max(1, (data and data.pages) or 1))
	applyKeys("detail")
end

-- WHAT COLOUR A CELL IS (§3.12): your own name is `PAPER` and everyone else's `BODY`; a NEGATIVE
-- points number is `CLAY`; a zero is `FIELD_MUTED`. PURE, because it is three rules and a spec can
-- hold all three.
function ReportPanel.cellColor(key: string, word: string, mine: boolean): Color3
	if key == "name" or key == "kind" then
		return if mine then Style.LOOK.PAPER else Style.LOOK.BODY
	end
	if key == "points" and string.sub(word, 1, 1) == "-" then
		return Style.LOOK.CLAY
	end
	if word == "0" then
		return Style.LOOK.FIELD_MUTED
	end
	return if mine then Style.LOOK.PAPER else Style.LOOK.BODY
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
	if scrim ~= nil then
		-- THE SCRIM GOES WITH THE PANEL, written here so there is ONE owner of "is the report open"
		-- and no frame can be left lying over the world after the panel has gone.
		(scrim :: Frame).Visible = open
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

-- WHETHER THIS PANEL OPENS ITSELF WHEN A DRIVE CLOSES. PURE and exported, and it takes the config,
-- so a spec drives BOTH states while the shipped value sits at one of them (task 159). It is FALSE
-- today, and `Report.CONFIG.AUTO_OPEN_AT_DRIVE_END` carries the whole reason with a screenshot.
function ReportPanel.autoOpensAtDriveEnd(cfg): boolean
	return (cfg or Report.CONFIG).AUTO_OPEN_AT_DRIVE_END == true
end

-- A DRIVE CLOSES (design section 8.4): if the panel is already open it does NOT jump -- it re-asks for
-- the same view, so the numbers settle into their final values and a player reading a detail stays in
-- it. If it is closed it opens ONCE **only when the config says it may** (task 159: it does not, and
-- the end of a drive is the results scene instead), and `autoOpenedFor` is why "once" is a fact:
-- Karen closing it must leave it closed.
local function onDriveChanged(event: any, cfg: any?)
	local kind = type(event) == "table" and event.kind or ""
	if kind == "driveClosed" then
		if open then
			if view == "detail" then
				ask({ drive = event.drive, hunter = payload and payload.userId, page = page })
			else
				ask({ drive = event.drive, page = 1 })
			end
		elseif ReportPanel.autoOpensAtDriveEnd(cfg) and autoOpenedFor ~= event.drive then
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
	scrim = collaborators and collaborators.scrim
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
